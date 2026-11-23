-- Le Grand Partage — autoriser les réponses aux conversations reçues
-- À exécuter dans Supabase > SQL Editor. Idempotent.

CREATE OR REPLACE FUNCTION public.can_send_listing_message(
  p_listing_id uuid,
  p_sender_id uuid,
  p_recipient_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = p_listing_id
      AND (
        -- Premier contact : un membre écrit au propriétaire de l'annonce.
        (l.user_id = p_recipient_id AND p_sender_id <> l.user_id)
        OR
        -- Réponse : le propriétaire répond à une personne ayant déjà contacté
        -- ce propriétaire au sujet de cette annonce.
        (l.user_id = p_sender_id AND EXISTS (
          SELECT 1 FROM public.messages m
          WHERE m.listing_id = p_listing_id
            AND m.sender_id = p_recipient_id
            AND m.recipient_id = p_sender_id
        ))
      )
  );
$$;

REVOKE ALL ON FUNCTION public.can_send_listing_message(uuid,uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_send_listing_message(uuid,uuid,uuid) TO authenticated;

DROP POLICY IF EXISTS "Sender writes own messages" ON public.messages;
CREATE POLICY "Participants send messages on listing conversations"
ON public.messages FOR INSERT TO authenticated
WITH CHECK (
  auth.uid() = sender_id
  AND public.can_send_listing_message(listing_id, sender_id, recipient_id)
);
