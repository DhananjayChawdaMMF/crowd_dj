-- Minimal stand-ins for the Supabase platform pieces the migrations depend on,
-- so the migrations and security tests can run on a plain local Postgres.
do $$ begin create role anon nologin; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated nologin; exception when duplicate_object then null; end $$;

create schema auth;
create table auth.users (id uuid primary key);
-- Tests impersonate users with: set request.uid = '<uuid>';
create function auth.uid() returns uuid language sql stable as
  $$ select nullif(current_setting('request.uid', true), '')::uuid $$;
grant usage on schema auth to authenticated, anon;
grant execute on function auth.uid() to authenticated, anon;

create publication supabase_realtime;

create schema realtime;
create table realtime.messages (extension text, topic text);
alter table realtime.messages enable row level security;
create function realtime.topic() returns text language sql as
  $$ select current_setting('realtime.topic', true) $$;
grant usage on schema realtime to authenticated, anon;
grant select, insert on realtime.messages to authenticated;
grant execute on function realtime.topic() to authenticated, anon;

grant usage on schema public to authenticated, anon;
-- Supabase grants table privileges to API roles by default; RLS is what
-- protects the data, so mirror that here (the tests must prove RLS holds).
alter default privileges in schema public grant all on tables to authenticated, anon;
alter default privileges in schema public grant all on sequences to authenticated, anon;
