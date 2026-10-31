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
