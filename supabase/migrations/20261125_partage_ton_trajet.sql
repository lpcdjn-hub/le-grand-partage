-- Le Grand Partage — Partage ton trajet
-- Exécuter ce script dans Supabase SQL Editor.
create table if not exists public.rides (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references auth.users(id) on delete cascade,
  departure_city text not null check (char_length(departure_city) between 2 and 100),
  arrival_city text not null check (char_length(arrival_city) between 2 and 100),
  stops text not null default '' check (char_length(stops) <= 500),
  departure_at timestamptz not null,
  seats_available integer not null check (seats_available between 1 and 8),
  details text not null default '' check (char_length(details) <= 1000),
  status text not null default 'open' check (status in ('open','full','cancelled','completed')),
  adults_only boolean not null default true check (adults_only = true),
  created_at timestamptz not null default now()
);
create index if not exists rides_open_departure_idx on public.rides (departure_at) where status = 'open';
create table if not exists public.ride_requests (
  id uuid primary key default gen_random_uuid(),
  ride_id uuid not null references public.rides(id) on delete cascade,
  requester_id uuid not null references auth.users(id) on delete cascade,
  seats_requested integer not null default 1 check (seats_requested between 1 and 4),
  message text not null default '' check (char_length(message) <= 500),
  status text not null default 'pending' check (status in ('pending','accepted','declined','cancelled')),
  created_at timestamptz not null default now(),
  unique (ride_id, requester_id)
);
alter table public.rides enable row level security;
alter table public.ride_requests enable row level security;
drop policy if exists "Anyone can view open rides" on public.rides;
create policy "Anyone can view open rides" on public.rides for select using (status = 'open' and departure_at > now());
drop policy if exists "Adults signed in can publish rides" on public.rides;
create policy "Adults signed in can publish rides" on public.rides for insert to authenticated with check (driver_id = auth.uid() and adults_only = true);
drop policy if exists "Drivers manage own rides" on public.rides;
create policy "Drivers manage own rides" on public.rides for update to authenticated using (driver_id = auth.uid()) with check (driver_id = auth.uid());
drop policy if exists "Drivers delete own rides" on public.rides;
create policy "Drivers delete own rides" on public.rides for delete to authenticated using (driver_id = auth.uid());
drop policy if exists "Requester creates own request" on public.ride_requests;
create policy "Requester creates own request" on public.ride_requests for insert to authenticated with check (requester_id = auth.uid() and exists (select 1 from public.rides r where r.id = ride_id and r.status = 'open' and r.driver_id <> auth.uid()));
drop policy if exists "Requester and driver read requests" on public.ride_requests;
create policy "Requester and driver read requests" on public.ride_requests for select to authenticated using (requester_id = auth.uid() or exists (select 1 from public.rides r where r.id = ride_id and r.driver_id = auth.uid()));
drop policy if exists "Requester or driver update requests" on public.ride_requests;
create policy "Requester or driver update requests" on public.ride_requests for update to authenticated using (requester_id = auth.uid() or exists (select 1 from public.rides r where r.id = ride_id and r.driver_id = auth.uid())) with check (requester_id = auth.uid() or exists (select 1 from public.rides r where r.id = ride_id and r.driver_id = auth.uid()));
grant select on public.rides to anon, authenticated;
grant insert, update, delete on public.rides to authenticated;
grant select, insert, update on public.ride_requests to authenticated;
