-- CrowdDJ security suite. Run with supabase/tests/run_local.sh.
-- Every check records PASS/FAIL in test.results; the script fails if any FAIL.
-- Users: a = host of room A, b = guest of A, c = stranger (no room),
--        d = host of room D, e = guest of D, f = host of room F (expiry test).

create schema test;
create table test.results (name text, ok boolean, detail text);
create table test.kv (k text primary key, v text);
grant usage on schema test to public;
grant all on test.results, test.kv to public;

create function test.as_user(p text) returns void language sql as
  $$ select set_config('request.uid', '00000000-0000-0000-0000-00000000000' || p, false) $$;
create function test.put(k text, v text) returns void language sql as
  $$ insert into test.kv values (k, v) on conflict (k) do update set v = excluded.v $$;
create function test.get(k text) returns text language sql as
  $$ select v from test.kv where kv.k = $1 $$;
create function test.check(p_name text, p_ok boolean, p_detail text default '')
  returns void language sql as
  $$ insert into test.results values (p_name, coalesce(p_ok, false), p_detail) $$;
create function test.expect_error(p_name text, p_sql text, p_fragment text)
  returns void language plpgsql as $$
declare v_msg text;
begin
  begin
    execute p_sql;
  exception when others then
    v_msg := sqlerrm;
  end;
  insert into test.results values
    (p_name, v_msg is not null and v_msg ilike '%' || p_fragment || '%',
     coalesce(v_msg, 'NO ERROR RAISED'));
end $$;
grant execute on all functions in schema test to public;

insert into auth.users (id)
select ('00000000-0000-0000-0000-00000000000' || x)::uuid
  from unnest(array['a','b','c','d','e','f','1']) as x;

set role authenticated;

------------------------------------------------------------------------------
-- 1. Room creation
------------------------------------------------------------------------------
select test.as_user('a');
select test.put('rid_a', public.create_room('Room A', 'desc', 'DJ A', false, true, true)->'room'->>'id');
select test.put('code_a', public.create_room('Room A2', null, 'DJ A')->'room'->>'room_code');
select test.check('room code is 10 random hex chars', test.get('code_a') ~ '^[0-9A-F]{10}$', test.get('code_a'));
select test.put('code_a', room_code) from public.rooms where id = test.get('rid_a')::uuid;

select test.expect_error('empty room name rejected', $q$select public.create_room('  ', null, 'DJ')$q$, 'invalid_room_name');
select test.expect_error('control chars in room name rejected', $q$select public.create_room(E'bad\x01name', null, 'DJ')$q$, 'invalid_room_name');
select test.expect_error('81-char room name rejected', format($q$select public.create_room(%L, null, 'DJ')$q$, repeat('x', 81)), 'invalid_room_name');
select test.expect_error('41-char host name rejected', format($q$select public.create_room('R', null, %L)$q$, repeat('x', 41)), 'invalid_display_name');
select test.expect_error('control chars in host name rejected', $q$select public.create_room('R', null, E'a\x07b')$q$, 'invalid_display_name');

select test.as_user('1');
do $$ begin
  for i in 1..5 loop perform public.create_room('R' || i, null, 'Spam'); end loop;
end $$;
select test.expect_error('6th active room for one user rejected', $q$select public.create_room('R6', null, 'Spam')$q$, 'too_many_active_rooms');

------------------------------------------------------------------------------
-- 2. Joining, previews, membership isolation
------------------------------------------------------------------------------
select test.as_user('b');
select test.check('guest joins as guest',
  public.join_room(test.get('code_a'), 'Bob')->'participant'->>'role' = 'guest');
select test.expect_error('empty guest name rejected', format($q$select public.join_room(%L, ' ')$q$, test.get('code_a')), 'invalid_display_name');
select test.expect_error('unknown code rejected', $q$select public.join_room('0000000000', 'x')$q$, 'room_not_found');

select test.as_user('c');
select test.check('stranger can preview by code (code is the capability)',
  public.get_room_preview(lower(test.get('code_a')))->>'room_name' = 'Room A');
select test.check('stranger sees no rooms', (select count(*) from public.rooms) = 0);
select test.check('stranger sees no participants', (select count(*) from public.participants) = 0);
select test.check('stranger sees no queue/recommendations/songs',
  (select count(*) from public.queue) + (select count(*) from public.recommendations)
  + (select count(*) from public.songs) = 0);

select test.as_user('a');
select test.check('host sees own room', (select count(*) from public.rooms where id = test.get('rid_a')::uuid) = 1);

------------------------------------------------------------------------------
-- 3. Direct writes are impossible for every role (host included)
------------------------------------------------------------------------------
do $$
declare t text; u text; n int; before_rooms text;
begin
  foreach u in array array['a','b','c'] loop
    perform test.as_user(u);
    foreach t in array array['rooms','participants','songs','recommendations','votes','queue'] loop
      begin
        execute format('update public.%I set id = id', t);
        get diagnostics n = row_count;
        perform test.check(format('user %s: UPDATE %s affects 0 rows', u, t), n = 0, n::text);
      exception when others then
        perform test.check(format('user %s: UPDATE %s denied', u, t), true, sqlerrm);
      end;
      begin
        execute format('delete from public.%I', t);
        get diagnostics n = row_count;
        perform test.check(format('user %s: DELETE %s affects 0 rows', u, t), n = 0, n::text);
      exception when others then
        perform test.check(format('user %s: DELETE %s denied', u, t), true, sqlerrm);
      end;
    end loop;
  end loop;
end $$;

select test.as_user('a');
select test.expect_error('host cannot INSERT into queue directly',
  format($q$insert into public.queue (room_id, song_id, position) values (%L, gen_random_uuid(), 0)$q$, test.get('rid_a')), 'row-level security');
select test.expect_error('host cannot INSERT a room directly',
  $q$insert into public.rooms (room_code, room_name, host_user_id) values ('HACKED0001', 'x', auth.uid())$q$, 'row-level security');
select test.expect_error('guest cannot make themselves host via participants',
  format($q$insert into public.participants (room_id, user_id, display_name, role) values (%L, auth.uid(), 'x', 'host')$q$, test.get('rid_a')), 'row-level security');
select test.check('room name unchanged after all attempts',
  (select room_name from public.rooms where id = test.get('rid_a')::uuid) = 'Room A');

------------------------------------------------------------------------------
-- 4. Recommendation input validation (client-supplied metadata is untrusted)
------------------------------------------------------------------------------
select test.as_user('b');
select test.put('rid_a_', test.get('rid_a'));
select test.expect_error('javascript: artwork rejected', format($q$select public.recommend_song(%L,'mock','x1','T','A',null,'javascript:alert(1)',1000)$q$, test.get('rid_a')), 'invalid_song');
select test.expect_error('http (non-https) artwork rejected', format($q$select public.recommend_song(%L,'mock','x1','T','A',null,'http://tracker.example/p.png',1000)$q$, test.get('rid_a')), 'invalid_song');
select test.expect_error('artwork with whitespace rejected', format($q$select public.recommend_song(%L,'mock','x1','T','A',null,'https://a.example/a b',1000)$q$, test.get('rid_a')), 'invalid_song');
select test.expect_error('201-char title rejected', format($q$select public.recommend_song(%L,'mock','x1',%L,'A')$q$, test.get('rid_a'), repeat('t', 201)), 'invalid_song');
select test.expect_error('control chars in title rejected', format($q$select public.recommend_song(%L,'mock','x1',E'bad\x01',  'A')$q$, test.get('rid_a')), 'invalid_song');
select test.expect_error('absurd duration rejected', format($q$select public.recommend_song(%L,'mock','x1','T','A',null,null,99999999999)$q$, test.get('rid_a')), 'invalid_song');
select test.expect_error('negative duration rejected', format($q$select public.recommend_song(%L,'mock','x1','T','A',null,null,-5)$q$, test.get('rid_a')), 'invalid_song');
select test.expect_error('malformed provider rejected', format($q$select public.recommend_song(%L,'Bad Provider!','x1','T','A')$q$, test.get('rid_a')), 'invalid_song');
select test.expect_error('empty artist rejected', format($q$select public.recommend_song(%L,'mock','x1','T','  ')$q$, test.get('rid_a')), 'invalid_song');

select test.check('valid recommendation (https artwork) accepted',
  (public.recommend_song(test.get('rid_a')::uuid, 'mock', 'p1', 'Song One', 'Artist', null,
                         'https://img.example/a.png', 180000)).status = 'pending');
select test.expect_error('duplicate pending song rejected',
  format($q$select public.recommend_song(%L,'mock','p1','Song One','Artist')$q$, test.get('rid_a')), 'already_recommended');

select test.as_user('c');
select test.expect_error('stranger cannot recommend',
  format($q$select public.recommend_song(%L,'mock','p9','T','A')$q$, test.get('rid_a')), 'forbidden');

------------------------------------------------------------------------------
-- 5. Host-only actions: guests and strangers are refused, host succeeds
------------------------------------------------------------------------------
select test.as_user('a');
select test.put('rec1', (select id::text from public.recommendations where room_id = test.get('rid_a')::uuid limit 1));

do $$
declare u text; rid text := test.get('rid_a'); rec text := test.get('rec1');
begin
  foreach u in array array['b','c'] loop
    perform test.as_user(u);
    perform test.expect_error(u || ': review_recommendation refused', format($q$select public.review_recommendation(%L, true)$q$, rec), 'forbidden');
    perform test.expect_error(u || ': set_playback refused', format($q$select public.set_playback(%L, 'playing', 0)$q$, rid), 'forbidden');
    perform test.expect_error(u || ': play_next refused', format($q$select public.play_next(%L, 0)$q$, rid), 'forbidden');
    perform test.expect_error(u || ': close_room refused', format($q$select public.close_room(%L)$q$, rid), 'forbidden');
  end loop;
end $$;

select test.as_user('a');
select test.check('host approves -> status approved', (public.review_recommendation(test.get('rec1')::uuid, true)).status = 'approved');
select test.check('approval enqueued the song at position 0',
  (select position from public.queue where recommendation_id = test.get('rec1')::uuid) = 0);
select test.expect_error('re-reviewing is rejected', format($q$select public.review_recommendation(%L, false)$q$, test.get('rec1')), 'already_reviewed');

select test.as_user('b');
select test.put('qid', (select id::text from public.queue where room_id = test.get('rid_a')::uuid limit 1));
select test.expect_error('guest cannot remove queue items', format($q$select public.remove_queue_item(%L)$q$, test.get('qid')), 'forbidden');

-- second song to prove positions are assigned by the backend, in order
select public.recommend_song(test.get('rid_a')::uuid, 'mock', 'p2', 'Song Two', 'Artist');
select test.as_user('a');
select public.review_recommendation((select id from public.recommendations where status = 'pending' and room_id = test.get('rid_a')::uuid limit 1), true);
select test.check('queue positions are 0,1 in approval order',
  (select string_agg(position::text, ',' order by position) from public.queue where room_id = test.get('rid_a')::uuid) = '0,1');

------------------------------------------------------------------------------
-- 6. Playback: validation, version guard against duplicate transitions
------------------------------------------------------------------------------
select test.expect_error('cannot play with no current song', format($q$select public.set_playback(%L,'playing',0)$q$, test.get('rid_a')), 'nothing_to_play');
select test.expect_error('negative position rejected', format($q$select public.set_playback(%L,'stopped',-1)$q$, test.get('rid_a')), 'invalid_playback');
select test.expect_error('position beyond 24h rejected', format($q$select public.set_playback(%L,'stopped',86400001)$q$, test.get('rid_a')), 'invalid_playback');
select test.expect_error('unknown status rejected', format($q$select public.set_playback(%L,'rewind',0)$q$, test.get('rid_a')), 'invalid_playback');

select test.put('v0', (select playback_version::text from public.rooms where id = test.get('rid_a')::uuid));
select test.check('play_next with the current version starts song one',
  (select current_song_id is not null and playback_status = 'playing'
          and playback_version = test.get('v0')::bigint + 1
     from public.play_next(test.get('rid_a')::uuid, test.get('v0')::bigint)));
select test.expect_error('duplicate play_next (stale version) rejected',
  format($q$select public.play_next(%L, %s)$q$, test.get('rid_a'), test.get('v0')), 'stale_playback_version');
select test.check('exactly one song is "playing" in the queue',
  (select count(*) from public.queue where room_id = test.get('rid_a')::uuid and status = 'playing') = 1);
select test.check('host can pause at a position',
  (select playback_status = 'paused' and playback_position_ms = 4200 from public.set_playback(test.get('rid_a')::uuid, 'paused', 4200)));

select test.as_user('b');
select test.check('guest can read the playback state',
  (select playback_status = 'paused' and playback_position_ms = 4200 from public.rooms where id = test.get('rid_a')::uuid));

select test.as_user('a');
select test.check('host removes the queued song',
  (select count(*) from public.queue where room_id = test.get('rid_a')::uuid and status = 'queued') = 1);
select public.remove_queue_item((select id from public.queue where room_id = test.get('rid_a')::uuid and status = 'queued'));
select test.check('removed song is no longer queued',
  (select count(*) from public.queue where room_id = test.get('rid_a')::uuid and status = 'queued') = 0);

------------------------------------------------------------------------------
-- 7. Songs are isolated per room (no cross-room metadata poisoning or leaks)
------------------------------------------------------------------------------
select test.as_user('d');
select test.put('rid_d', public.create_room('Room D', null, 'DJ D', false, true, false)->'room'->>'id');
select test.put('code_d', (select room_code from public.rooms where id = test.get('rid_d')::uuid));
select test.as_user('e');
select public.join_room(test.get('code_d'), 'Eve');
select public.recommend_song(test.get('rid_d')::uuid, 'mock', 'p1', 'Real Title', 'Real Artist');
select test.check('room D shows its own metadata for the same provider id',
  (select s.title from public.recommendations r join public.songs s on s.id = r.song_id
    where r.room_id = test.get('rid_d')::uuid) = 'Real Title');
select test.check('guest of D cannot see room A songs',
  (select count(*) from public.songs where title = 'Song One') = 0);
select test.as_user('b');
select test.check('guest of A cannot see room D songs',
  (select count(*) from public.songs where title = 'Real Title') = 0);
reset role;
select test.check('owner view: mock:p1 stored once per room',
  (select count(*) from public.songs where provider_song_id = 'p1') = 2);
set role authenticated;

------------------------------------------------------------------------------
-- 8. Voting
------------------------------------------------------------------------------
select test.as_user('b');
select test.put('rec_vote', (public.recommend_song(test.get('rid_a')::uuid, 'mock', 'p3', 'Song Three', 'Artist')).id::text);
select public.vote_recommendation(test.get('rec_vote')::uuid, 1::smallint);
select public.vote_recommendation(test.get('rec_vote')::uuid, (-1)::smallint);
select test.check('re-voting replaces the vote (one row, now -1)',
  (select count(*) from public.votes where recommendation_id = test.get('rec_vote')::uuid) = 1
  and (select vote_type from public.votes where recommendation_id = test.get('rec_vote')::uuid) = -1);
select test.expect_error('invalid vote value rejected', format($q$select public.vote_recommendation(%L, 5::smallint)$q$, test.get('rec_vote')), 'invalid_vote');
select test.as_user('c');
select test.expect_error('stranger cannot vote', format($q$select public.vote_recommendation(%L, 1::smallint)$q$, test.get('rec_vote')), 'forbidden');
select test.as_user('e');
select test.expect_error('voting disabled rooms refuse votes (via other room rec)',
  format($q$select public.vote_recommendation((select id from public.recommendations where room_id = %L limit 1), 1::smallint)$q$, test.get('rid_d')), 'voting_disabled');

------------------------------------------------------------------------------
-- 9. Rate limits and caps
------------------------------------------------------------------------------
select test.as_user('e');
do $$
begin
  for i in 1..4 loop
    perform public.recommend_song(test.get('rid_d')::uuid, 'mock', 'r' || i, 'Rate ' || i, 'A');
  end loop;
end $$;
select test.expect_error('6th recommendation within a minute is rate limited',
  format($q$select public.recommend_song(%L,'mock','r5','Rate 5','A')$q$, test.get('rid_d')), 'rate_limited');

reset role;
-- fill room D to the participant cap using direct inserts as the table owner
insert into auth.users (id) select gen_random_uuid() from generate_series(1, 300);
insert into public.participants (room_id, user_id, display_name, role)
select test.get('rid_d')::uuid, id, 'Filler', 'guest'
  from auth.users where id not in (select user_id from public.participants) and id not in
       ('00000000-0000-0000-0000-00000000000a','00000000-0000-0000-0000-00000000000b','00000000-0000-0000-0000-00000000000c','00000000-0000-0000-0000-000000000001')
 limit (300 - (select count(*) from public.participants where room_id = test.get('rid_d')::uuid));
select test.check('room D is at the 300 participant cap',
  (select count(*) from public.participants where room_id = test.get('rid_d')::uuid) = 300);
set role authenticated;
select test.as_user('b');
select test.expect_error('new participant refused when the room is full',
  format($q$select public.join_room(%L, 'Late')$q$, test.get('code_d')), 'room_full');
select test.as_user('e');
select test.check('existing participant can still rejoin a full room',
  public.join_room(test.get('code_d'), 'Eve again')->'participant'->>'display_name' = 'Eve again');

------------------------------------------------------------------------------
-- 10. Roles: anon cannot do anything, internals are not callable
------------------------------------------------------------------------------
set role anon;
select test.expect_error('anon cannot create rooms', $q$select public.create_room('x', null, 'x')$q$, 'permission denied');
select test.expect_error('anon cannot join', $q$select public.join_room('0000000000', 'x')$q$, 'permission denied');
select test.expect_error('anon cannot preview', $q$select public.get_room_preview('0000000000')$q$, 'permission denied');
select test.check('anon reads no rooms', (select count(*) from public.rooms) = 0);
select test.check('anon reads no songs', (select count(*) from public.songs) = 0);
set role authenticated;
select test.as_user('a');
select test.expect_error('internal _uid() is not callable', $q$select public._uid()$q$, 'permission denied');
select test.expect_error('internal _host_room() is not callable', format($q$select public._host_room(%L)$q$, test.get('rid_a')), 'permission denied');
select test.expect_error('purge_stale_rooms is not callable by clients', $q$select public.purge_stale_rooms()$q$, 'permission denied');

------------------------------------------------------------------------------
-- 11. Expiry and closed rooms refuse writes
------------------------------------------------------------------------------
select test.as_user('f');
select test.put('rid_f', public.create_room('Room F', null, 'DJ F')->'room'->>'id');
select test.put('code_f', (select room_code from public.rooms where id = test.get('rid_f')::uuid));
reset role;
update public.rooms set expires_at = now() - interval '1 hour' where id = test.get('rid_f')::uuid;
set role authenticated;
select test.as_user('b');
select test.expect_error('expired room refuses joins', format($q$select public.join_room(%L, 'x')$q$, test.get('code_f')), 'room_closed');
select test.check('preview reports expired room as closed',
  public.get_room_preview(test.get('code_f'))->>'status' = 'closed');
select test.as_user('f');
select test.expect_error('expired room refuses host writes', format($q$select public.set_playback(%L,'stopped',0)$q$, test.get('rid_f')), 'room_closed');

select test.as_user('a');
select public.close_room(test.get('rid_a')::uuid);
select test.expect_error('closing twice is refused', format($q$select public.close_room(%L)$q$, test.get('rid_a')), 'room_closed');
select test.as_user('b');
select test.expect_error('closed room refuses recommendations', format($q$select public.recommend_song(%L,'mock','z1','T','A')$q$, test.get('rid_a')), 'room_closed');
select test.expect_error('closed room refuses votes', format($q$select public.vote_recommendation(%L, 1::smallint)$q$, test.get('rec_vote')), 'room_closed');
select test.as_user('c');
select test.expect_error('closed room refuses new joins', format($q$select public.join_room(%L,'x')$q$, test.get('code_a')), 'room_closed');
select test.as_user('a');
select test.expect_error('closed room refuses host playback writes', format($q$select public.set_playback(%L,'stopped',0)$q$, test.get('rid_a')), 'room_closed');
select test.check('members can still read the closed room (to show "closed")',
  (select status from public.rooms where id = test.get('rid_a')::uuid) = 'closed');

------------------------------------------------------------------------------
-- 12. Realtime presence authorization
------------------------------------------------------------------------------
reset role;
select set_config('realtime.topic', 'room:' || test.get('rid_d'), false);
insert into realtime.messages (extension, topic) values ('presence', 'x');
set role authenticated;
select test.as_user('e');
select test.check('room member can receive presence for their room', (select count(*) from realtime.messages) = 1);
select test.as_user('c');
select test.check('stranger cannot receive presence for the room', (select count(*) from realtime.messages) = 0);
select test.expect_error('stranger cannot announce presence in the room',
  $q$insert into realtime.messages (extension, topic) values ('presence', 'y')$q$, 'row-level security');
select test.check('topic helper rejects malformed topics',
  public.is_room_topic_member('room:not-a-uuid') = false and public.is_room_topic_member('other:' || test.get('rid_d')) = false);
select test.check('server_time() returns a timestamp', public.server_time() is not null);

------------------------------------------------------------------------------
-- 13. Cleanup job
------------------------------------------------------------------------------
reset role;
update public.rooms set expires_at = now() - interval '9 days', playback_updated_at = now() - interval '9 days'
 where id = test.get('rid_a')::uuid;
do $$
declare v_removed int;
begin
  begin
    v_removed := public.purge_stale_rooms();
  exception when undefined_function then
    perform test.check('purge_stale_rooms exists', false, 'function missing');
    return;
  end;
  perform test.check('purge_stale_rooms removes old closed rooms', v_removed >= 1, v_removed::text);
  perform test.check('purge cascades to participants, songs, recommendations, queue',
    (select count(*) from public.participants where room_id = test.get('rid_a')::uuid)
    + (select count(*) from public.songs where room_id = test.get('rid_a')::uuid)
    + (select count(*) from public.recommendations where room_id = test.get('rid_a')::uuid)
    + (select count(*) from public.queue where room_id = test.get('rid_a')::uuid) = 0);
  perform test.check('purge keeps rooms that are still active',
    (select count(*) from public.rooms where id = test.get('rid_d')::uuid) = 1);
end $$;

------------------------------------------------------------------------------
-- Report
------------------------------------------------------------------------------
select case when ok then 'PASS' else 'FAIL' end as result, name,
       case when ok then '' else detail end as detail
  from test.results order by ok, name;

do $$
declare failed int; total int;
begin
  select count(*) filter (where not ok), count(*) into failed, total from test.results;
  raise notice '% checks, % failed', total, failed;
  if failed > 0 then raise exception 'SECURITY SUITE FAILED (% of % checks)', failed, total; end if;
end $$;
