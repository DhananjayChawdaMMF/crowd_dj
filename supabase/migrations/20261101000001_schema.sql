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
