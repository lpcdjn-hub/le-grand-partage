-- Le Grand Partage — privacy of member profiles + public aggregate count
-- Run in Supabase SQL Editor. Idempotent.

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Profiles are publicly readable" ON public.profiles;
DROP POLICY IF EXISTS "Members read own profile" ON public.profiles;
CREATE POLICY "Members read own profile"
ON public.profiles FOR SELECT TO authenticated
USING (auth.uid() = id OR public.is_admin());

-- Public can retrieve only the aggregate count, never profile rows.
CREATE OR REPLACE FUNCTION public.public_member_count()
RETURNS bigint
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT count(*)::bigint FROM public.profiles;
$$;

REVOKE ALL ON FUNCTION public.public_member_count() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.public_member_count() TO anon, authenticated;
