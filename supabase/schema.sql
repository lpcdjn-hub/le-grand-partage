-- Le Grand Partage — schéma initial Supabase
-- À exécuter une seule fois dans Supabase > Éditeur SQL > Nouvelle requête.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Membre',
  city text,
  created_at timestamptz not null default now()
);

create table if not exists public.listings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 3 and 90),
  category text not null check (category in ('Maison','Vêtements','Enfants','Loisirs','Bricolage','Autre')),
  city text not null,
  country text,
  region text,
  description text not null default '',
  image_url text,
  status text not null default 'available' check (status in ('available','reserved','given')),
  created_at timestamptz not null default now()
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now(),
  check (sender_id <> recipient_id)
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  listing_id uuid references public.listings(id) on delete cascade,
  reason text not null check (char_length(reason) between 5 and 1000),
  created_at timestamptz not null default now()
);

create index if not exists listings_created_at_idx on public.listings(created_at desc);
create index if not exists listings_category_idx on public.listings(category);
create index if not exists messages_listing_created_idx on public.messages(listing_id, created_at);

alter table public.profiles enable row level security;
alter table public.listings enable row level security;
alter table public.messages enable row level security;
alter table public.reports enable row level security;

drop policy if exists "Profiles are publicly readable" on public.profiles;
create policy "Profiles are publicly readable" on public.profiles for select using (true);
drop policy if exists "Members create own profile" on public.profiles;
create policy "Members create own profile" on public.profiles for insert to authenticated with check (auth.uid() = id);
drop policy if exists "Members update own profile" on public.profiles;
create policy "Members update own profile" on public.profiles for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "Anyone can read available listings" on public.listings;
create policy "Anyone can read available listings" on public.listings for select using (true);
drop policy if exists "Members create own listings" on public.listings;
create policy "Members create own listings" on public.listings for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "Members update own listings" on public.listings;
create policy "Members update own listings" on public.listings for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "Members delete own listings" on public.listings;
create policy "Members delete own listings" on public.listings for delete to authenticated using (auth.uid() = user_id);

drop policy if exists "Participants read their messages" on public.messages;
create policy "Participants read their messages" on public.messages for select to authenticated using (auth.uid() = sender_id or auth.uid() = recipient_id);
-- Autorise le premier contact vers le propriétaire de l'annonce et les réponses dans la conversation.
create or replace function public.can_send_message(p_listing_id uuid, p_sender_id uuid, p_recipient_id uuid)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select
    p_sender_id <> p_recipient_id
    and exists (
      select 1 from public.listings l
      where l.id = p_listing_id
        and l.user_id in (p_sender_id, p_recipient_id)
    )
    and (
      exists (
        select 1 from public.listings l
        where l.id = p_listing_id and l.user_id = p_recipient_id
      )
      or exists (
        select 1 from public.messages m
        where m.listing_id = p_listing_id
          and ((m.sender_id = p_sender_id and m.recipient_id = p_recipient_id)
            or (m.sender_id = p_recipient_id and m.recipient_id = p_sender_id))
      )
    );
$$;

-- Autorise le premier contact vers le propriétaire de l'annonce et les réponses dans la conversation.
create or replace function public.can_send_message(p_listing_id uuid, p_sender_id uuid, p_recipient_id uuid)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select
    p_sender_id <> p_recipient_id
    and exists (
      select 1 from public.listings l
      where l.id = p_listing_id
        and l.user_id in (p_sender_id, p_recipient_id)
    )
    and (
      exists (
        select 1 from public.listings l
        where l.id = p_listing_id and l.user_id = p_recipient_id
      )
      or exists (
        select 1 from public.messages m
        where m.listing_id = p_listing_id
          and ((m.sender_id = p_sender_id and m.recipient_id = p_recipient_id)
            or (m.sender_id = p_recipient_id and m.recipient_id = p_sender_id))
      )
    );
$$;

drop policy if exists "Sender writes own messages" on public.messages;
drop policy if exists "Participants send messages" on public.messages;
create policy "Participants send messages" on public.messages
for insert to authenticated
with check (
  auth.uid() = sender_id
  and public.can_send_message(listing_id, sender_id, recipient_id)
);

drop policy if exists "Members submit reports" on public.reports;
create policy "Members submit reports" on public.reports for insert to authenticated with check (auth.uid() = reporter_id);
drop policy if exists "Members read own reports" on public.reports;
create policy "Members read own reports" on public.reports for select to authenticated using (auth.uid() = reporter_id);

-- Création automatique du profil lors d'une inscription.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(nullif(new.raw_user_meta_data ->> 'display_name',''), 'Membre'))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Espace public pour les photos d'annonces.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('listing-photos', 'listing-photos', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = true, file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg','image/png','image/webp'];

drop policy if exists "Public can view listing photos" on storage.objects;
create policy "Public can view listing photos" on storage.objects for select using (bucket_id = 'listing-photos');
drop policy if exists "Members upload own listing photos" on storage.objects;
create policy "Members upload own listing photos" on storage.objects for insert to authenticated
with check (bucket_id = 'listing-photos' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "Members delete own listing photos" on storage.objects;
create policy "Members delete own listing photos" on storage.objects for delete to authenticated
using (bucket_id = 'listing-photos' and (storage.foldername(name))[1] = auth.uid()::text);
