-- Le Grand Partage — fonctions du tableau Super-Admin
-- À exécuter dans Supabase SQL Editor APRÈS la création de public.admin_users.
-- Les RPC vérifient le rôle dans la base avant toute donnée/action sensible.

create or replace function public.admin_list_users()
returns table(user_id uuid,email text,display_name text,created_at timestamptz,is_suspended boolean)
language plpgsql security definer set search_path=public,auth
as $$
begin
 if not public.is_admin() then raise exception 'Unauthorized'; end if;
 return query
 select u.id,u.email,coalesce(p.display_name,''),u.created_at,
   exists(select 1 from public.admin_suspensions s where s.user_id=u.id)
 from auth.users u left join public.profiles p on p.id=u.id
 order by u.created_at desc limit 500;
end $$;
grant execute on function public.admin_list_users() to authenticated;

create or replace function public.admin_list_listings()
returns table(id uuid,user_id uuid,title text,category text,city text,description text,image_url text,status text,created_at timestamptz)
language plpgsql security definer set search_path=public
as $$
begin
 if not public.is_admin() then raise exception 'Unauthorized'; end if;
 return query select l.id,l.user_id,l.title,l.category,l.city,l.description,l.image_url,l.status,l.created_at
 from public.listings l order by l.created_at desc limit 500;
end $$;
grant execute on function public.admin_list_listings() to authenticated;

create or replace function public.admin_delete_listing(p_listing_id uuid)
returns void language plpgsql security definer set search_path=public
as $$
begin
 if not public.is_admin() then raise exception 'Unauthorized'; end if;
 delete from public.listings where id=p_listing_id;
end $$;
grant execute on function public.admin_delete_listing(uuid) to authenticated;

create or replace function public.admin_set_suspension(p_user_id uuid,p_suspended boolean,p_reason text default '')
returns void language plpgsql security definer set search_path=public
as $$
begin
 if not public.is_admin() then raise exception 'Unauthorized'; end if;
 if p_user_id=auth.uid() then raise exception 'Cannot suspend yourself'; end if;
 if p_suspended then
  insert into public.admin_suspensions(user_id,reason,suspended_by)
  values(p_user_id,coalesce(p_reason,''),auth.uid())
  on conflict(user_id) do update set reason=excluded.reason,suspended_at=now(),suspended_by=auth.uid();
 else
  delete from public.admin_suspensions where user_id=p_user_id;
 end if;
end $$;
grant execute on function public.admin_set_suspension(uuid,boolean,text) to authenticated;

-- Compatible with the existing public.reports table; adds moderation status.
alter table public.reports add column if not exists status text not null default 'open';
create or replace function public.admin_list_reports()
returns table(id uuid,listing_id uuid,reporter_id uuid,reason text,details text,status text,created_at timestamptz)
language plpgsql security definer set search_path=public
as $$
begin
 if not public.is_admin() then raise exception 'Unauthorized'; end if;
 return query select r.id,r.listing_id,r.user_id,r.reason,''::text,r.status,r.created_at
 from public.reports r order by r.created_at desc limit 500;
end $$;
grant execute on function public.admin_list_reports() to authenticated;

create or replace function public.admin_update_report(p_report_id uuid,p_status text)
returns void language plpgsql security definer set search_path=public
as $$
begin
 if not public.is_admin() then raise exception 'Unauthorized'; end if;
 if p_status not in ('open','reviewed','closed') then raise exception 'Invalid status'; end if;
 update public.reports set status=p_status where id=p_report_id;
end $$;
grant execute on function public.admin_update_report(uuid,text) to authenticated;
