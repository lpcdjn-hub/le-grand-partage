-- Le Grand Partage : accès administrateur à la messagerie
-- À exécuter dans Supabase SQL Editor.
-- La fonction is_admin() existante contrôle le rôle administrateur.
create or replace function public.admin_list_messages()
returns table (
  id uuid,
  sender_id uuid,
  recipient_id uuid,
  sender_name text,
  recipient_name text,
  body text,
  created_at timestamptz,
  listing_id uuid,
  listing_title text
)
language sql
security definer
set search_path = public
as $$
  select
    m.id,
    m.sender_id,
    m.recipient_id,
    coalesce(ps.display_name, 'Utilisateur') as sender_name,
    coalesce(pr.display_name, 'Utilisateur') as recipient_name,
    m.body,
    m.created_at,
    m.listing_id,
    l.title as listing_title
  from public.messages m
  left join public.profiles ps on ps.id = m.sender_id
  left join public.profiles pr on pr.id = m.recipient_id
  left join public.listings l on l.id = m.listing_id
  where public.is_admin() = true
  order by m.created_at desc
  limit 1000;
$$;

revoke all on function public.admin_list_messages() from public, anon;
grant execute on function public.admin_list_messages() to authenticated;
