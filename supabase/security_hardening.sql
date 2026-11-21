-- Le Grand Partage — security hardening
-- Run in Supabase SQL Editor. Idempotent; does not delete data.
-- Suspended users cannot create/update/delete listings, messages, reports, profiles, or upload photos.

CREATE OR REPLACE FUNCTION public.is_suspended(p_user_id uuid DEFAULT auth.uid())
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.admin_suspensions s WHERE s.user_id = p_user_id
  );
$$;
REVOKE ALL ON FUNCTION public.is_suspended(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_suspended(uuid) TO authenticated;

-- Profiles: users can only update their own profile, and must not be suspended.
DROP POLICY IF EXISTS "Members update own profile" ON public.profiles;
CREATE POLICY "Members update own profile"
ON public.profiles FOR UPDATE TO authenticated
USING (auth.uid() = id AND NOT public.is_suspended(auth.uid()))
WITH CHECK (auth.uid() = id AND NOT public.is_suspended(auth.uid()));

-- Listings
DROP POLICY IF EXISTS "Members create own listings" ON public.listings;
CREATE POLICY "Members create own listings"
ON public.listings FOR INSERT TO authenticated
WITH CHECK (auth.uid() = user_id AND NOT public.is_suspended(auth.uid()));

DROP POLICY IF EXISTS "Members update own listings" ON public.listings;
CREATE POLICY "Members update own listings"
ON public.listings FOR UPDATE TO authenticated
USING (auth.uid() = user_id AND NOT public.is_suspended(auth.uid()))
WITH CHECK (auth.uid() = user_id AND NOT public.is_suspended(auth.uid()));

DROP POLICY IF EXISTS "Members delete own listings" ON public.listings;
CREATE POLICY "Members delete own listings"
ON public.listings FOR DELETE TO authenticated
USING (auth.uid() = user_id AND NOT public.is_suspended(auth.uid()));

-- Messages
DROP POLICY IF EXISTS "Sender writes own messages" ON public.messages;
CREATE POLICY "Sender writes own messages"
ON public.messages FOR INSERT TO authenticated
WITH CHECK (
  auth.uid() = sender_id
  AND NOT public.is_suspended(auth.uid())
  AND EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = listing_id AND l.user_id = recipient_id
  )
);

-- Reports
DROP POLICY IF EXISTS "Members submit reports" ON public.reports;
DROP POLICY IF EXISTS "authenticated submit reports" ON public.reports;
CREATE POLICY "Members submit reports"
ON public.reports FOR INSERT TO authenticated
WITH CHECK (auth.uid() = reporter_id AND NOT public.is_suspended(auth.uid()));

-- Storage uploads
DROP POLICY IF EXISTS "Members upload own listing photos" ON storage.objects;
CREATE POLICY "Members upload own listing photos"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'listing-photos'
  AND (storage.foldername(name))[1] = auth.uid()::text
  AND NOT public.is_suspended(auth.uid())
);

DROP POLICY IF EXISTS "Members delete own listing photos" ON storage.objects;
CREATE POLICY "Members delete own listing photos"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'listing-photos'
  AND (storage.foldername(name))[1] = auth.uid()::text
  AND NOT public.is_suspended(auth.uid())
);

-- Ensure admin suspension table is protected.
ALTER TABLE public.admin_suspensions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "admins manage suspensions" ON public.admin_suspensions;
CREATE POLICY "admins manage suspensions"
ON public.admin_suspensions FOR ALL TO authenticated
USING (public.is_admin()) WITH CHECK (public.is_admin());
