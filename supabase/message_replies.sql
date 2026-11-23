-- Le Grand Partage — autoriser les réponses dans les conversations
-- À exécuter dans Supabase > SQL Editor. Idempotent.
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

revoke all on function public.can_send_message(uuid,uuid,uuid) from public;
grant execute on function public.can_send_message(uuid,uuid,uuid) to authenticated;

drop policy if exists "Sender writes own messages" on public.messages;
drop policy if exists "Participants send messages" on public.messages;
drop policy if exists "Participants send messages on listing conversations" on public.messages;
create policy "Participants send messages"
on public.messages for insert to authenticated
with check (
  auth.uid() = sender_id
  and public.can_send_message(listing_id, sender_id, recipient_id)
);
