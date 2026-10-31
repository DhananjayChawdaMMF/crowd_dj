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
