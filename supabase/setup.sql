-- GENERATED: concatenation of migrations/*.sql in order. For pasting into the Supabase SQL editor on a fresh project.
-- Do not run on a project that already has these migrations applied.

-- ===== supabase/migrations/20261101000001_schema.sql =====
-- CrowdDJ core schema. All writes happen through SECURITY DEFINER RPCs (see 0003).

create table public.rooms (
  id uuid primary key default gen_random_uuid(),
  room_code text not null unique,
  room_name text not null check (char_length(room_name) between 1 and 80),
  description text check (char_length(description) <= 500),
  host_user_id uuid not null references auth.users (id) on delete cascade,
  status text not null default 'active' check (status in ('active', 'closed')),
  is_public boolean not null default false,
  allow_recommendations boolean not null default true,
  enable_voting boolean not null default false,
  current_song_id uuid,
  playback_status text not null default 'stopped'
    check (playback_status in ('stopped', 'playing', 'paused')),
  playback_position_ms bigint not null default 0 check (playback_position_ms >= 0),
  playback_updated_at timestamptz not null default now(),
  playback_version bigint not null default 0,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours')
);
create index rooms_host_idx on public.rooms (host_user_id);

create table public.participants (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 40),
  role text not null check (role in ('host', 'guest')),
  joined_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  unique (room_id, user_id)
);
create index participants_room_idx on public.participants (room_id);

create table public.songs (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  provider_song_id text not null,
  title text not null,
  artist text not null,
  album_name text,
  artwork_url text,
  duration_ms bigint check (duration_ms is null or duration_ms >= 0),
  created_at timestamptz not null default now(),
  unique (provider, provider_song_id)
);

alter table public.rooms
  add constraint rooms_current_song_fk
  foreign key (current_song_id) references public.songs (id) on delete set null;

create table public.recommendations (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms (id) on delete cascade,
  song_id uuid not null references public.songs (id) on delete cascade,
  participant_id uuid not null references public.participants (id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users (id) on delete set null
);
create index recommendations_room_status_idx
  on public.recommendations (room_id, status, created_at);

create table public.votes (
  id uuid primary key default gen_random_uuid(),
  recommendation_id uuid not null references public.recommendations (id) on delete cascade,
  participant_id uuid not null references public.participants (id) on delete cascade,
  vote_type smallint not null check (vote_type in (-1, 1)),
  created_at timestamptz not null default now(),
  unique (recommendation_id, participant_id)
);

create table public.queue (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms (id) on delete cascade,
  song_id uuid not null references public.songs (id) on delete cascade,
  recommendation_id uuid references public.recommendations (id) on delete set null,
  added_by uuid references auth.users (id) on delete set null,
  position integer not null check (position >= 0),
  status text not null default 'queued'
    check (status in ('queued', 'playing', 'played', 'removed')),
  created_at timestamptz not null default now(),
  played_at timestamptz,
  unique (room_id, position)
);
create index queue_room_status_idx on public.queue (room_id, status, position);

-- ===== supabase/migrations/20261101000002_rls.sql =====
-- Row Level Security. Clients may only READ (as room members); every write goes
-- through the RPCs in the next migration. No INSERT/UPDATE/DELETE policies exist,
-- so direct table writes from the client are denied.

alter table public.rooms enable row level security;
alter table public.participants enable row level security;
alter table public.songs enable row level security;
alter table public.recommendations enable row level security;
alter table public.votes enable row level security;
alter table public.queue enable row level security;

-- Helpers. SECURITY DEFINER so policies don't recurse through participants' own RLS.
create function public.is_room_member(p_room_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.participants
    where room_id = p_room_id and user_id = (select auth.uid())
  );
$$;

create function public.is_room_host(p_room_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.rooms
    where id = p_room_id and host_user_id = (select auth.uid())
  );
$$;

revoke all on function public.is_room_member(uuid) from public, anon;
revoke all on function public.is_room_host(uuid) from public, anon;
grant execute on function public.is_room_member(uuid) to authenticated;
grant execute on function public.is_room_host(uuid) to authenticated;

create policy rooms_select_members on public.rooms
  for select to authenticated
  using (public.is_room_member(id));

create policy participants_select_members on public.participants
  for select to authenticated
  using (public.is_room_member(room_id));

create policy recommendations_select_members on public.recommendations
  for select to authenticated
  using (public.is_room_member(room_id));

create policy votes_select_members on public.votes
  for select to authenticated
  using (exists (
    select 1 from public.recommendations r
    where r.id = recommendation_id and public.is_room_member(r.room_id)
  ));

create policy queue_select_members on public.queue
  for select to authenticated
  using (public.is_room_member(room_id));

-- Songs are shared catalog metadata; readable by signed-in users, written only via RPC.
create policy songs_select_authenticated on public.songs
  for select to authenticated
  using (true);

-- Realtime (postgres_changes honours the SELECT policies above).
alter publication supabase_realtime add table
  public.rooms, public.participants, public.recommendations, public.queue;

-- ===== supabase/migrations/20261101000003_rpc.sql =====
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

-- ===== supabase/migrations/20261101000004_realtime_and_clock.sql =====
-- Phase 5: authorize the private presence channel and expose the server clock.
--
-- Presence topics are `room:<room uuid>`. Only members of that room may join
-- (receive) or announce themselves (send) on it. Also disable "Allow public
-- access" under Project Settings -> Realtime so private-channel authorization
-- is enforced for every channel.

create function public.is_room_topic_member(p_topic text)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select case
    when p_topic ~ '^room:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then public.is_room_member(substr(p_topic, 6)::uuid)
    else false
  end;
$$;

revoke all on function public.is_room_topic_member(text) from public, anon;
grant execute on function public.is_room_topic_member(text) to authenticated;

create policy room_presence_receive on realtime.messages
  for select to authenticated
  using (
    realtime.messages.extension in ('presence')
    and public.is_room_topic_member((select realtime.topic()))
  );

create policy room_presence_send on realtime.messages
  for insert to authenticated
  with check (
    realtime.messages.extension in ('presence')
    and public.is_room_topic_member((select realtime.topic()))
  );

-- Lets clients correct for a wrong local clock when extrapolating playback.
create function public.server_time()
returns timestamptz
language sql stable
set search_path = ''
as $$ select now(); $$;

revoke all on function public.server_time() from public, anon;
grant execute on function public.server_time() to authenticated;

-- ===== supabase/migrations/20261101000005_hardening.sql =====
-- Phase 6 hardening, from the security review.
--
-- F1  songs is a shared table written with client-supplied metadata: the first
--     writer of (provider, provider_song_id) wins, so one guest could plant fake
--     titles / tracking artwork URLs that every other room then displays.
--     -> songs become per-room (unique per room), so a room only ever shows
--        metadata submitted by its own members, and inputs are validated.
-- F2  No input bounds on song / name fields.
-- F3  No cap on participants or pending recommendations per room.
-- F4  Control characters allowed in display names.
-- F5  review_recommendation locked recommendation -> room while other paths
--     lock room -> recommendation (deadlock risk). Lock room first.
-- F6  set_playback accepted any position.
-- F7  Missing FK indexes; no cleanup for expired rooms.

-- Safe to re-run: every step is idempotent and the script keeps no session
-- state (no temp tables, no BEGIN/COMMIT), because the Supabase SQL editor may
-- run statements separately. A half-applied earlier attempt is completed.

----------------------------------------------------------------------------
-- F1: songs scoped to a room
----------------------------------------------------------------------------
alter table public.songs add column if not exists room_id uuid references public.rooms (id) on delete cascade;
alter table public.songs drop constraint if exists songs_provider_provider_song_id_key;

-- Existing rows (created before this migration) belong to the room that first
-- recommended them ...
update public.songs s
   set room_id = (select r.room_id from public.recommendations r
                   where r.song_id = s.id order by r.created_at limit 1)
 where s.room_id is null;

-- ... and every other room that referenced the same row gets its own copy.
-- One self-contained statement (no temp table: the SQL editor does not keep
-- session state between statements). Data-modifying CTEs see one snapshot and
-- foreign keys are checked at the end of the statement, so the copies exist by
-- the time the references are re-pointed.
with split as materialized (
select distinct r.song_id as old_id, r.room_id, gen_random_uuid() as new_id
  from public.recommendations r
  join public.songs s on s.id = r.song_id
 where r.room_id <> s.room_id
),
copies as (
insert into public.songs (id, room_id, provider, provider_song_id, title, artist,
                          album_name, artwork_url, duration_ms, created_at)
select m.new_id, m.room_id, s.provider, s.provider_song_id, s.title, s.artist,
       s.album_name, s.artwork_url, s.duration_ms, s.created_at
  from split m join public.songs s on s.id = m.old_id
returning id
),
repoint_recs as (
update public.recommendations r set song_id = m.new_id
  from split m where r.song_id = m.old_id and r.room_id = m.room_id
returning r.id
),
repoint_queue as (
update public.queue q set song_id = m.new_id
  from split m where q.song_id = m.old_id and q.room_id = m.room_id
returning q.id
),
repoint_rooms as (
update public.rooms rm set current_song_id = m.new_id
  from split m where rm.current_song_id = m.old_id and rm.id = m.room_id
returning rm.id
)
select (select count(*) from copies)
   + (select count(*) from repoint_recs)
   + (select count(*) from repoint_queue)
   + (select count(*) from repoint_rooms) as rows_touched;

-- Rows nobody references are removed.
delete from public.songs where room_id is null;

alter table public.songs alter column room_id set not null;
alter table public.songs drop constraint if exists songs_room_provider_song_key;
alter table public.songs add constraint songs_room_provider_song_key
  unique (room_id, provider, provider_song_id);

-- Sanitise rows written before the bounds existed so the constraints can apply.
update public.songs set
  artwork_url = case when artwork_url ~ '^https://[^[:space:]]+$'
                      and char_length(artwork_url) <= 500 then artwork_url end,
  duration_ms = case when duration_ms between 0 and 7200000 then duration_ms end,
  title = coalesce(nullif(left(btrim(regexp_replace(title, '[[:cntrl:]]', '', 'g')), 200), ''), 'Untitled'),
  artist = coalesce(nullif(left(btrim(regexp_replace(artist, '[[:cntrl:]]', '', 'g')), 200), ''), 'Unknown'),
  album_name = nullif(left(btrim(regexp_replace(coalesce(album_name, ''), '[[:cntrl:]]', '', 'g')), 200), ''),
  provider = coalesce(nullif(left(regexp_replace(lower(provider), '[^a-z0-9_-]', '', 'g'), 32), ''), 'unknown'),
  provider_song_id = left(provider_song_id, 128);

-- Bounds (also enforced in the RPC with friendly errors; these are the backstop).
alter table public.songs
  drop constraint if exists songs_title_len,
  drop constraint if exists songs_artist_len,
  drop constraint if exists songs_album_len,
  drop constraint if exists songs_provider_fmt,
  drop constraint if exists songs_provider_id_len,
  drop constraint if exists songs_artwork_https,
  drop constraint if exists songs_duration_range;
alter table public.songs
  add constraint songs_title_len check (char_length(title) between 1 and 200),
  add constraint songs_artist_len check (char_length(artist) between 1 and 200),
  add constraint songs_album_len check (album_name is null or char_length(album_name) <= 200),
  add constraint songs_provider_fmt check (provider ~ '^[a-z0-9_-]{1,32}$'),
  add constraint songs_provider_id_len check (char_length(provider_song_id) between 1 and 128),
  add constraint songs_artwork_https check (
    artwork_url is null or (artwork_url ~ '^https://[^[:space:]]+$' and char_length(artwork_url) <= 500)),
  add constraint songs_duration_range check (duration_ms is null or duration_ms between 0 and 7200000);

drop policy if exists songs_select_authenticated on public.songs;
drop policy if exists songs_select_members on public.songs;
create policy songs_select_members on public.songs
  for select to authenticated
  using (public.is_room_member(room_id));

----------------------------------------------------------------------------
-- F7: indexes for foreign keys used by policies / cascades
----------------------------------------------------------------------------
create index if not exists songs_room_idx on public.songs (room_id);
create index if not exists rooms_current_song_idx on public.rooms (current_song_id);
create index if not exists recommendations_song_idx on public.recommendations (song_id);
create index if not exists recommendations_participant_idx on public.recommendations (participant_id);
create index if not exists queue_song_idx on public.queue (song_id);
create index if not exists queue_recommendation_idx on public.queue (recommendation_id);
create index if not exists votes_participant_idx on public.votes (participant_id);
create index if not exists participants_user_idx on public.participants (user_id);

----------------------------------------------------------------------------
-- Replaced functions (CREATE OR REPLACE keeps the existing grants)
----------------------------------------------------------------------------

create or replace function public.create_room(
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
  v_name text := btrim(coalesce(p_room_name, ''));
  v_host text := btrim(coalesce(p_host_name, ''));
  v_desc text := nullif(btrim(coalesce(p_description, '')), '');
begin
  if char_length(v_name) not between 1 and 80 or v_name ~ '[[:cntrl:]]' then
    raise exception 'invalid_room_name';
  end if;
  if char_length(v_host) not between 1 and 40 or v_host ~ '[[:cntrl:]]' then
    raise exception 'invalid_display_name';
  end if;
  if v_desc is not null and char_length(v_desc) > 500 then
    raise exception 'invalid_room_name';
  end if;
  if (select count(*) from public.rooms
      where host_user_id = v_uid and status = 'active') >= 5 then
    raise exception 'too_many_active_rooms';
  end if;

  loop
    v_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
    begin
      insert into public.rooms (
        room_code, room_name, description, host_user_id,
        is_public, allow_recommendations, enable_voting
      ) values (
        v_code, v_name, v_desc, v_uid, coalesce(p_is_public, false),
        coalesce(p_allow_recommendations, true), coalesce(p_enable_voting, false)
      ) returning * into v_room;
      exit;
    exception when unique_violation then
      v_attempt := v_attempt + 1;
      if v_attempt > 5 then raise exception 'code_generation_failed'; end if;
    end;
  end loop;

  insert into public.participants (room_id, user_id, display_name, role)
  values (v_room.id, v_uid, v_host, 'host')
  returning * into v_part;

  return jsonb_build_object('room', to_jsonb(v_room), 'participant', to_jsonb(v_part));
end;
$$;

create or replace function public.join_room(p_code text, p_display_name text)
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
  if char_length(v_name) not between 1 and 40 or v_name ~ '[[:cntrl:]]' then
    raise exception 'invalid_display_name';
  end if;
  select id into v_id from public.rooms where room_code = upper(btrim(p_code));
  if v_id is null then raise exception 'room_not_found'; end if;
  v_room := public._open_room(v_id);

  -- Cap the room size, but never lock out someone who already joined.
  if not exists (select 1 from public.participants
                 where room_id = v_room.id and user_id = v_uid)
     and (select count(*) from public.participants where room_id = v_room.id) >= 300 then
    raise exception 'room_full';
  end if;

  insert into public.participants (room_id, user_id, display_name, role)
  values (v_room.id, v_uid, v_name,
          case when v_room.host_user_id = v_uid then 'host' else 'guest' end)
  on conflict (room_id, user_id)
  do update set display_name = excluded.display_name, last_seen_at = now()
  returning * into v_part;

  return jsonb_build_object('room', to_jsonb(v_room), 'participant', to_jsonb(v_part));
end;
$$;

create or replace function public.recommend_song(
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
  v_title text := btrim(coalesce(p_title, ''));
  v_artist text := btrim(coalesce(p_artist, ''));
  v_album text := nullif(btrim(coalesce(p_album_name, '')), '');
begin
  v_room := public._open_room(p_room_id);
  select * into v_part from public.participants
    where room_id = p_room_id and user_id = v_uid;
  if not found then raise exception 'forbidden'; end if;
  if not v_room.allow_recommendations then
    raise exception 'recommendations_disabled';
  end if;

  -- Song metadata comes from the client: bound and sanitise everything.
  if p_provider is null or p_provider !~ '^[a-z0-9_-]{1,32}$'
     or p_provider_song_id is null
     or char_length(p_provider_song_id) not between 1 and 128
     or p_provider_song_id ~ '[[:cntrl:]]'
     or char_length(v_title) not between 1 and 200 or v_title ~ '[[:cntrl:]]'
     or char_length(v_artist) not between 1 and 200 or v_artist ~ '[[:cntrl:]]'
     or (v_album is not null and (char_length(v_album) > 200 or v_album ~ '[[:cntrl:]]'))
     or (p_artwork_url is not null
         and (p_artwork_url !~ '^https://[^[:space:]]+$' or char_length(p_artwork_url) > 500))
     or (p_duration_ms is not null and p_duration_ms not between 0 and 7200000) then
    raise exception 'invalid_song';
  end if;

  -- Rate limits: per guest (5/min, 10 pending) and per room (200 pending).
  if (select count(*) from public.recommendations
      where participant_id = v_part.id and created_at > now() - interval '1 minute') >= 5
     or (select count(*) from public.recommendations
         where participant_id = v_part.id and status = 'pending') >= 10
     or (select count(*) from public.recommendations
         where room_id = p_room_id and status = 'pending') >= 200 then
    raise exception 'rate_limited';
  end if;

  -- Songs are per room: a room only ever shows metadata its own members sent.
  insert into public.songs (room_id, provider, provider_song_id, title, artist,
                            album_name, artwork_url, duration_ms)
  values (p_room_id, p_provider, p_provider_song_id, v_title, v_artist,
          v_album, p_artwork_url, p_duration_ms)
  on conflict (room_id, provider, provider_song_id)
  do update set provider = excluded.provider
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

-- Lock order is always room -> recommendation (matches recommend_song).
create or replace function public.review_recommendation(p_recommendation_id uuid, p_approve boolean)
returns public.recommendations
language plpgsql security definer
set search_path = ''
as $$
declare
  v_uid uuid := public._uid();
  v_room_id uuid;
  v_rec public.recommendations;
begin
  select room_id into v_room_id from public.recommendations
    where id = p_recommendation_id;
  if v_room_id is null then raise exception 'recommendation_not_found'; end if;
  perform public._host_room(v_room_id);

  select * into v_rec from public.recommendations
    where id = p_recommendation_id for update;
  if v_rec.status <> 'pending' then raise exception 'already_reviewed'; end if;

  update public.recommendations
    set status = case when p_approve then 'approved' else 'rejected' end,
        reviewed_at = now(), reviewed_by = v_uid
    where id = v_rec.id
    returning * into v_rec;

  if p_approve then
    insert into public.queue (room_id, song_id, recommendation_id, added_by, position)
    values (v_rec.room_id, v_rec.song_id, v_rec.id, v_uid,
            (select coalesce(max(position), -1) + 1
               from public.queue where room_id = v_rec.room_id));
  end if;
  return v_rec;
end;
$$;

create or replace function public.set_playback(
  p_room_id uuid,
  p_status text,
  p_position_ms bigint
) returns public.rooms
language plpgsql security definer
set search_path = ''
as $$
declare r public.rooms;
begin
  if p_status not in ('playing', 'paused', 'stopped')
     or p_position_ms is null or p_position_ms not between 0 and 86400000 then
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

----------------------------------------------------------------------------
-- F7: cleanup (run on a schedule by pg_cron or an Edge Function; not callable
-- by clients)
----------------------------------------------------------------------------
create or replace function public.purge_stale_rooms(p_older_than interval default interval '7 days')
returns integer
language plpgsql security definer
set search_path = ''
as $$
declare v_count integer;
begin
  -- Songs, queue, recommendations, votes and participants cascade.
  delete from public.rooms
   where (status = 'closed' or expires_at < now())
     and greatest(expires_at, playback_updated_at) < now() - p_older_than;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.purge_stale_rooms(interval) from public, anon, authenticated;
