-- Le Grand Partage — profile privacy hardening
-- Apply only after reviewing and testing on Supabase. Does not delete data.
-- Public listing names are exposed only for owners of available listings.
-- Inbox names are exposed only for users with whom the caller has a conversation.

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Profiles are publicly readable" ON public.profiles;
-- Remove every existing SELECT policy on profiles. Policies are OR-combined,
-- so an older permissive policy would otherwise keep profiles publicly readable.
DO $
DECLARE policy_name text;
BEGIN
  FOR policy_name IN
    SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'profiles' AND cmd = 'SELECT'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.profiles', policy_name);
  END LOOP;
END $;
CREATE POLICY "Members read own profile"
ON public.profiles FOR SELECT TO authenticated
USING (auth.uid() = id OR public.is_admin());

CREATE OR REPLACE FUNCTION public.public_listing_member_names(p_user_ids uuid[])
RETURNS TABLE(user_id uuid, display_name text)
LANGUAGE sql SECURITY DEFINER SET search_path = ''
AS $$
  SELECT DISTINCT p.id, COALESCE(p.display_name, 'Membre')
  FROM public.profiles p
  JOIN public.listings l ON l.user_id = p.id
  WHERE p.id = ANY(p_user_ids) AND l.status = 'available';
$$;
REVOKE ALL ON FUNCTION public.public_listing_member_names(uuid[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.public_listing_member_names(uuid[]) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.inbox_member_names(p_user_ids uuid[])
RETURNS TABLE(user_id uuid, display_name text)
LANGUAGE sql SECURITY DEFINER SET search_path = ''
AS $$
  SELECT DISTINCT p.id, COALESCE(p.display_name, 'Membre')
  FROM public.profiles p
  WHERE auth.uid() IS NOT NULL AND p.id = ANY(p_user_ids)
    AND EXISTS (
      SELECT 1 FROM public.messages m
      WHERE (m.sender_id = auth.uid() AND m.recipient_id = p.id)
         OR (m.recipient_id = auth.uid() AND m.sender_id = p.id)
    );
$$;
REVOKE ALL ON FUNCTION public.inbox_member_names(uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.inbox_member_names(uuid[]) TO authenticated;

CREATE OR REPLACE FUNCTION public.public_member_count()
RETURNS bigint
LANGUAGE sql SECURITY DEFINER SET search_path = ''
AS $$ SELECT count(*)::bigint FROM public.profiles; $$;
REVOKE ALL ON FUNCTION public.public_member_count() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.public_member_count() TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
