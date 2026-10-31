-- Trusted operations. Every function:
--   * is SECURITY DEFINER with an empty search_path (all names schema-qualified)
--   * derives identity from auth.uid() only (never a client-supplied user id)
--   * validates room status/expiry, membership and, for host actions, ownership
--   * is executable by `authenticated` only (anonymous sign-ins use that role)

-- Returns the caller's uid or raises.
create function public._uid()
returns uuid
language plpgsql stable
set search_path = ''
as $$
declare v uuid := (select auth.uid());
begin
  if v is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  return v;
end;
$$;

-- Locks and returns an open room, or raises.
create function public._open_room(p_room_id uuid)
returns public.rooms
language plpgsql
set search_path = ''
as $$
declare r public.rooms;
begin
  select * into r from public.rooms where id = p_room_id for update;
  if not found then raise exception 'room_not_found'; end if;
  if r.status <> 'active' or r.expires_at <= now() then
    raise exception 'room_closed';
  end if;
  return r;
end;
$$;

-- Locks an open room and checks the caller is its host.
create function public._host_room(p_room_id uuid)
returns public.rooms
language plpgsql
set search_path = ''
as $$
declare r public.rooms;
begin
  r := public._open_room(p_room_id);
  if r.host_user_id <> public._uid() then
    raise exception 'forbidden';
  end if;
  return r;
end;
$$;

create function public.create_room(
  p_room_name text,
  p_description text,
  p_host_name text,
  p_is_public boolean default false,
  p_allow_recommendations boolean default true,
  p_enable_voting boolean default false
) returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  v_uid uuid := public._uid();
  v_room public.rooms;
  v_part public.participants;
  v_code text;
  v_attempt int := 0;
begin
  if char_length(btrim(coalesce(p_room_name, ''))) not between 1 and 80 then
    raise exception 'invalid_room_name';
  end if;
  if char_length(btrim(coalesce(p_host_name, ''))) not between 1 and 40 then
    raise exception 'invalid_display_name';
  end if;
  if (select count(*) from public.rooms
      where host_user_id = v_uid and status = 'active') >= 5 then
    raise exception 'too_many_active_rooms';
  end if;

  loop
    -- 10 hex chars from a CSPRNG-backed UUID: unguessable, non-sequential.
    v_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
    begin
      insert into public.rooms (
        room_code, room_name, description, host_user_id,
        is_public, allow_recommendations, enable_voting
      ) values (
        v_code, btrim(p_room_name), nullif(btrim(coalesce(p_description, '')), ''),
        v_uid, coalesce(p_is_public, false),
        coalesce(p_allow_recommendations, true), coalesce(p_enable_voting, false)
      ) returning * into v_room;
      exit;
    exception when unique_violation then
      v_attempt := v_attempt + 1;
      if v_attempt > 5 then raise exception 'code_generation_failed'; end if;
    end;
  end loop;

  insert into public.participants (room_id, user_id, display_name, role)
  values (v_room.id, v_uid, btrim(p_host_name), 'host')
  returning * into v_part;

  return jsonb_build_object('room', to_jsonb(v_room), 'participant', to_jsonb(v_part));
end;
$$;

-- Minimal info for the join screen. The code itself is the capability.
create function public.get_room_preview(p_code text)
returns jsonb
language plpgsql stable security definer
set search_path = ''
as $$
declare r public.rooms; v_host text;
begin
  perform public._uid();
  select * into r from public.rooms where room_code = upper(btrim(p_code));
  if not found then raise exception 'room_not_found'; end if;
  select display_name into v_host from public.participants
    where room_id = r.id and role = 'host';
  return jsonb_build_object(
    'room_code', r.room_code,
    'room_name', r.room_name,
    'description', r.description,
    'status', case when r.status = 'active' and r.expires_at > now()
                   then 'active' else 'closed' end,
    'host_name', v_host,
    'is_host', r.host_user_id = (select auth.uid()),
    'my_display_name', (select p.display_name from public.participants p
                        where p.room_id = r.id and p.user_id = (select auth.uid()))
  );
end;
$$;

create function public.join_room(p_code text, p_display_name text)
returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  v_uid uuid := public._uid();
  v_id uuid;
  v_room public.rooms;
  v_part public.participants;
  v_name text := btrim(coalesce(p_display_name, ''));
begin
  if char_length(v_name) not between 1 and 40 then
    raise exception 'invalid_display_name';
  end if;
  select id into v_id from public.rooms where room_code = upper(btrim(p_code));
  if v_id is null then raise exception 'room_not_found'; end if;
  v_room := public._open_room(v_id);

  -- One identity per (room, user). Role is derived, never client-supplied.
  insert into public.participants (room_id, user_id, display_name, role)
  values (v_room.id, v_uid, v_name,
          case when v_room.host_user_id = v_uid then 'host' else 'guest' end)
  on conflict (room_id, user_id)
  do update set display_name = excluded.display_name, last_seen_at = now()
  returning * into v_part;

  return jsonb_build_object('room', to_jsonb(v_room), 'participant', to_jsonb(v_part));
end;
$$;

create function public.touch_participant(p_room_id uuid)
returns void
language sql security definer
set search_path = ''
as $$
  update public.participants set last_seen_at = now()
  where room_id = p_room_id and user_id = (select auth.uid());
$$;

create function public.recommend_song(
  p_room_id uuid,
  p_provider text,
  p_provider_song_id text,
  p_title text,
  p_artist text,
  p_album_name text default null,
  p_artwork_url text default null,
  p_duration_ms bigint default null
) returns public.recommendations
language plpgsql security definer
set search_path = ''
as $$
declare
  v_uid uuid := public._uid();
  v_room public.rooms;
  v_part public.participants;
  v_song uuid;
  v_rec public.recommendations;
begin
  v_room := public._open_room(p_room_id);
  select * into v_part from public.participants
    where room_id = p_room_id and user_id = v_uid;
  if not found then raise exception 'forbidden'; end if;
  if not v_room.allow_recommendations then
    raise exception 'recommendations_disabled';
  end if;
  if coalesce(btrim(p_title), '') = '' or coalesce(btrim(p_artist), '') = ''
     or coalesce(btrim(p_provider), '') = '' or coalesce(btrim(p_provider_song_id), '') = '' then
    raise exception 'invalid_song';
  end if;

  -- Rate limit: 5 recommendations per participant per minute, 10 pending max.
  if (select count(*) from public.recommendations
      where participant_id = v_part.id and created_at > now() - interval '1 minute') >= 5
     or (select count(*) from public.recommendations
         where participant_id = v_part.id and status = 'pending') >= 10 then
    raise exception 'rate_limited';
  end if;

  insert into public.songs (provider, provider_song_id, title, artist,
                            album_name, artwork_url, duration_ms)
  values (p_provider, p_provider_song_id, btrim(p_title), btrim(p_artist),
          p_album_name, p_artwork_url, p_duration_ms)
  on conflict (provider, provider_song_id) do update set provider = excluded.provider
  returning id into v_song;

  if exists (select 1 from public.recommendations
             where room_id = p_room_id and song_id = v_song and status = 'pending')
     or exists (select 1 from public.queue
                where room_id = p_room_id and song_id = v_song
                  and status in ('queued', 'playing')) then
    raise exception 'already_recommended';
  end if;

  insert into public.recommendations (room_id, song_id, participant_id)
  values (p_room_id, v_song, v_part.id)
  returning * into v_rec;
  return v_rec;
end;
$$;

-- Host approves (and enqueues atomically) or rejects.
create function public.review_recommendation(p_recommendation_id uuid, p_approve boolean)
returns public.recommendations
language plpgsql security definer
set search_path = ''
as $$
declare
  v_uid uuid := public._uid();
  v_rec public.recommendations;
begin
  select * into v_rec from public.recommendations
    where id = p_recommendation_id for update;
  if not found then raise exception 'recommendation_not_found'; end if;
  perform public._host_room(v_rec.room_id);
  if v_rec.status <> 'pending' then raise exception 'already_reviewed'; end if;

  update public.recommendations
    set status = case when p_approve then 'approved' else 'rejected' end,
        reviewed_at = now(), reviewed_by = v_uid
    where id = v_rec.id
    returning * into v_rec;

  if p_approve then
    -- Room row is locked by _host_room, so positions are assigned serially.
    insert into public.queue (room_id, song_id, recommendation_id, added_by, position)
    values (v_rec.room_id, v_rec.song_id, v_rec.id, v_uid,
            (select coalesce(max(position), -1) + 1
               from public.queue where room_id = v_rec.room_id));
  end if;
  return v_rec;
end;
$$;

create function public.vote_recommendation(p_recommendation_id uuid, p_vote_type smallint)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  v_uid uuid := public._uid();
  v_rec public.recommendations;
  v_room public.rooms;
  v_part uuid;
begin
  if p_vote_type not in (-1, 1) then raise exception 'invalid_vote'; end if;
  select * into v_rec from public.recommendations where id = p_recommendation_id;
  if not found then raise exception 'recommendation_not_found'; end if;
  v_room := public._open_room(v_rec.room_id);
  if not v_room.enable_voting then raise exception 'voting_disabled'; end if;
  if v_rec.status <> 'pending' then raise exception 'already_reviewed'; end if;
  select id into v_part from public.participants
    where room_id = v_rec.room_id and user_id = v_uid;
  if v_part is null then raise exception 'forbidden'; end if;

  insert into public.votes (recommendation_id, participant_id, vote_type)
  values (p_recommendation_id, v_part, p_vote_type)
  on conflict (recommendation_id, participant_id)
  do update set vote_type = excluded.vote_type;
end;
$$;

create function public.remove_queue_item(p_queue_id uuid)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare v_room uuid;
begin
  select room_id into v_room from public.queue where id = p_queue_id;
  if v_room is null then raise exception 'queue_item_not_found'; end if;
  perform public._host_room(v_room);
  update public.queue set status = 'removed'
    where id = p_queue_id and status = 'queued';
end;
$$;

-- Host play/pause/seek. Bumps playback_version so guests can reconcile.
create function public.set_playback(
  p_room_id uuid,
  p_status text,
  p_position_ms bigint
) returns public.rooms
language plpgsql security definer
set search_path = ''
as $$
declare r public.rooms;
begin
  if p_status not in ('playing', 'paused', 'stopped') or p_position_ms < 0 then
    raise exception 'invalid_playback';
  end if;
  r := public._host_room(p_room_id);
  if r.current_song_id is null and p_status <> 'stopped' then
    raise exception 'nothing_to_play';
  end if;
  update public.rooms
    set playback_status = p_status,
        playback_position_ms = p_position_ms,
        playback_updated_at = now(),
        playback_version = playback_version + 1
    where id = p_room_id
    returning * into r;
  return r;
end;
$$;

-- Advance to the next queued song. Idempotent per version: if the host client
-- fires "ended" twice (or skip + ended), the second call sees a newer version
-- and is rejected instead of skipping another song.
create function public.play_next(p_room_id uuid, p_expected_version bigint)
returns public.rooms
language plpgsql security definer
set search_path = ''
as $$
declare
  r public.rooms;
  v_next public.queue;
begin
  r := public._host_room(p_room_id);
  if r.playback_version <> p_expected_version then
    raise exception 'stale_playback_version';
  end if;

  update public.queue set status = 'played', played_at = now()
    where room_id = p_room_id and status = 'playing';

  select * into v_next from public.queue
    where room_id = p_room_id and status = 'queued'
    order by position limit 1 for update;

  if found then
    update public.queue set status = 'playing' where id = v_next.id;
    update public.rooms
      set current_song_id = v_next.song_id, playback_status = 'playing',
          playback_position_ms = 0, playback_updated_at = now(),
          playback_version = playback_version + 1
      where id = p_room_id returning * into r;
  else
    update public.rooms
      set current_song_id = null, playback_status = 'stopped',
          playback_position_ms = 0, playback_updated_at = now(),
          playback_version = playback_version + 1
      where id = p_room_id returning * into r;
  end if;
  return r;
end;
$$;

create function public.close_room(p_room_id uuid)
returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  perform public._host_room(p_room_id);
  update public.rooms
    set status = 'closed', playback_status = 'stopped',
        playback_updated_at = now(), playback_version = playback_version + 1
    where id = p_room_id;
end;
$$;

-- Lock everything down, then grant explicitly. Internal helpers get no grants.
revoke all on function
  public._uid(), public._open_room(uuid), public._host_room(uuid),
  public.create_room(text, text, text, boolean, boolean, boolean),
  public.get_room_preview(text),
  public.join_room(text, text),
  public.touch_participant(uuid),
  public.recommend_song(uuid, text, text, text, text, text, text, bigint),
  public.review_recommendation(uuid, boolean),
  public.vote_recommendation(uuid, smallint),
  public.remove_queue_item(uuid),
  public.set_playback(uuid, text, bigint),
  public.play_next(uuid, bigint),
  public.close_room(uuid)
from public, anon, authenticated;

grant execute on function
  public.create_room(text, text, text, boolean, boolean, boolean),
  public.get_room_preview(text),
  public.join_room(text, text),
  public.touch_participant(uuid),
  public.recommend_song(uuid, text, text, text, text, text, text, bigint),
  public.review_recommendation(uuid, boolean),
  public.vote_recommendation(uuid, smallint),
  public.remove_queue_item(uuid),
  public.set_playback(uuid, text, bigint),
  public.play_next(uuid, bigint),
  public.close_room(uuid)
to authenticated;
