-- Le Grand Partage — partage facultatif de la position GPS avec le Super-Admin
-- À exécuter dans Supabase SQL Editor. Les coordonnées précises ne sont jamais publiques.

create table if not exists public.member_locations (
  user_id uuid primary key references auth.users(id) on delete cascade,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  accuracy_m double precision,
  shared_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.member_locations enable row level security;
revoke all on public.member_locations from anon, authenticated;

create or replace function public.member_share_location(
  p_latitude double precision,
  p_longitude double precision,
  p_accuracy_m double precision
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'Unauthorized'; end if;
  if p_latitude is null or p_longitude is null
     or p_latitude not between -90 and 90
     or p_longitude not between -180 and 180 then
    raise exception 'Invalid coordinates';
  end if;
  insert into public.member_locations(user_id,latitude,longitude,accuracy_m,shared_at,updated_at)
  values(auth.uid(),p_latitude,p_longitude,p_accuracy_m,now(),now())
  on conflict(user_id) do update set
    latitude=excluded.latitude,
    longitude=excluded.longitude,
    accuracy_m=excluded.accuracy_m,
    shared_at=now(),
    updated_at=now();
end;
$$;
grant execute on function public.member_share_location(double precision,double precision,double precision) to authenticated;

create or replace function public.member_revoke_location()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'Unauthorized'; end if;
  delete from public.member_locations where user_id=auth.uid();
end;
$$;
grant execute on function public.member_revoke_location() to authenticated;

create or replace function public.admin_list_member_locations()
returns table(
  user_id uuid,
  email text,
  display_name text,
  city text,
  latitude double precision,
  longitude double precision,
  accuracy_m double precision,
  shared_at timestamptz
)
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.is_admin() then raise exception 'Unauthorized'; end if;
  return query
    select u.id,u.email::text,coalesce(p.display_name,'Membre')::text,p.city::text,
           ml.latitude,ml.longitude,ml.accuracy_m,ml.shared_at
    from public.member_locations ml
    join auth.users u on u.id=ml.user_id
    left join public.profiles p on p.id=ml.user_id
    order by ml.updated_at desc
    limit 500;
end;
$$;
grant execute on function public.admin_list_member_locations() to authenticated;

create or replace function public.member_location_shared()
returns boolean
language sql
security definer
set search_path = ''
as $$
  select auth.uid() is not null and exists (
    select 1 from public.member_locations where user_id=auth.uid()
  );
$$;
grant execute on function public.member_location_shared() to authenticated;
