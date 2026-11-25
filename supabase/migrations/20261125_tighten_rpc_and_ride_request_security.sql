-- Le Grand Partage — durcissement des RPC et demandes de trajets
revoke execute on all functions in schema public from anon, public;

grant execute on function public.public_member_count() to anon, authenticated;
grant execute on function public.public_listing_member_names(uuid[]) to anon, authenticated;

grant execute on function public.is_admin() to authenticated;
grant execute on function public.is_suspended(uuid) to authenticated;
grant execute on function public.can_send_message(uuid, uuid, uuid) to authenticated;
grant execute on function public.inbox_member_names(uuid[]) to authenticated;
grant execute on function public.member_location_shared() to authenticated;
grant execute on function public.member_share_location(double precision, double precision, double precision) to authenticated;
grant execute on function public.member_revoke_location() to authenticated;
grant execute on function public.admin_delete_listing(uuid) to authenticated;
grant execute on function public.admin_list_listings() to authenticated;
grant execute on function public.admin_list_member_locations() to authenticated;
grant execute on function public.admin_list_messages() to authenticated;
grant execute on function public.admin_list_reports() to authenticated;
grant execute on function public.admin_list_users() to authenticated;
grant execute on function public.admin_set_suspension(uuid, boolean, text) to authenticated;
grant execute on function public.admin_update_report(uuid, text) to authenticated;

create or replace function public.is_suspended(p_user_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path = public
as $$
  select auth.uid() is not null
     and p_user_id = auth.uid()
     and exists (select 1 from public.admin_suspensions s where s.user_id = auth.uid());
$$;

create or replace function public.can_send_message(p_listing_id uuid, p_sender_id uuid, p_recipient_id uuid)
returns boolean language sql security definer set search_path = ''
as $$
  select auth.uid() is not null
    and p_sender_id = auth.uid()
    and p_sender_id <> p_recipient_id
    and exists (
      select 1 from public.listings l
      where l.id = p_listing_id and l.user_id in (p_sender_id, p_recipient_id)
    )
    and (
      exists (select 1 from public.listings l where l.id = p_listing_id and l.user_id = p_recipient_id)
      or exists (
        select 1 from public.messages m
        where m.listing_id = p_listing_id
          and ((m.sender_id = p_sender_id and m.recipient_id = p_recipient_id)
            or (m.sender_id = p_recipient_id and m.recipient_id = p_sender_id))
      )
    );
$$;

drop policy if exists "Requester or driver update requests" on public.ride_requests;
create policy "Driver manages request status" on public.ride_requests
for update to authenticated
using (exists (select 1 from public.rides r where r.id = ride_id and r.driver_id = auth.uid()))
with check (exists (select 1 from public.rides r where r.id = ride_id and r.driver_id = auth.uid()));
