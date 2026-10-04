-- DEBORY Chemistry Lab Pro - Admin Center setup. Run ONCE in Supabase > SQL Editor.
create table if not exists public.admins(user_id uuid primary key references auth.users(id) on delete cascade);
alter table public.admins enable row level security;
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as
$$ select exists(select 1 from public.admins where user_id=auth.uid()) $$;

create table if not exists public.questions(id uuid primary key default gen_random_uuid(), qtype text not null,
  question text not null check(length(question)<1000), opts jsonb not null, answer int not null check(answer between 0 and 3),
  explanation text default '', created_at timestamptz default now());
create table if not exists public.resources(id uuid primary key default gen_random_uuid(), title text not null check(length(title)<300),
  url text not null check(url ~* '^https?://'), kind text default 'Link', created_at timestamptz default now());
create table if not exists public.visits(id uuid primary key, ip text check(length(ip)<=64), country text check(length(country)<=80),
  cc text check(length(cc)<=3), city text check(length(city)<=80), device text check(length(device)<=80), browser text check(length(browser)<=40),
  ua text check(length(ua)<=300), bot boolean default false, reason text default '', secs int default 0, interacted boolean default false,
  created_at timestamptz default now(), last_seen timestamptz default now());
create table if not exists public.banned_ips(ip text primary key, created_at timestamptz default now());

alter table public.questions enable row level security;
alter table public.resources enable row level security;
alter table public.visits enable row level security;
alter table public.banned_ips enable row level security;

create policy "read questions" on public.questions for select using(true);
create policy "admin questions" on public.questions for all using(public.is_admin()) with check(public.is_admin());
create policy "read resources" on public.resources for select using(true);
create policy "admin resources" on public.resources for all using(public.is_admin()) with check(public.is_admin());
create policy "log visit" on public.visits for insert to anon, authenticated with check(true);
create policy "admin visits" on public.visits for all using(public.is_admin()) with check(public.is_admin());
create policy "admin bans" on public.banned_ips for all using(public.is_admin()) with check(public.is_admin());

create or replace function public.is_banned(p_ip text) returns boolean language sql stable security definer set search_path=public as
$$ select exists(select 1 from public.banned_ips where ip=p_ip) $$;
create or replace function public.visit_ping(p_id uuid,p_secs int,p_int boolean,p_bot boolean,p_reason text) returns void
language sql security definer set search_path=public as
$$ update public.visits set secs=greatest(secs,least(p_secs,86400)), interacted=interacted or p_int, bot=bot or p_bot,
   reason=case when p_bot and coalesce(reason,'')='' then left(p_reason,120) else reason end, last_seen=now() where id=p_id $$;

-- AFTER creating your admin user (Authentication > Users > Add user, tick "Auto Confirm User"), run this with YOUR email:
-- insert into public.admins(user_id) select id from auth.users where email='YOUR_ADMIN_EMAIL';
