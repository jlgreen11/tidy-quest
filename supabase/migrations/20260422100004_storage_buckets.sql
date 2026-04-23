-- =============================================================================
-- TidyQuest — Storage Bucket Config
-- 20260422100004_storage_buckets.sql
--
-- Creates the proof-photos private bucket and configures RLS policies on
-- storage.objects so that:
--   - Parents can SELECT objects in their family's path.
--   - Children can INSERT (upload) objects in their family's path.
--   - No DELETE from client — service_role only (photo.purge-expired function).
--
-- Object path convention: <family_id>/<chore_instance_id>/<filename>
-- The family_id prefix is the only path-based security boundary; the iOS
-- client must use this exact prefix when uploading. The edge function
-- chore-instance.complete validates that the uploaded path matches the
-- authenticated user's family before accepting proof_photo_id.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Bucket creation
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'proof-photos',
  'proof-photos',
  false,              -- private; no public read
  10485760,           -- 10 MB per file
  ARRAY['image/jpeg','image/png','image/heic','image/heif','image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public              = EXCLUDED.public,
  file_size_limit     = EXCLUDED.file_size_limit,
  allowed_mime_types  = EXCLUDED.allowed_mime_types;

-- ---------------------------------------------------------------------------
-- RLS: enable row-level security on storage.objects
-- (Supabase enables this by default but we make it explicit)
-- ---------------------------------------------------------------------------
-- Note: storage.objects RLS is already enabled by Supabase; we add our policies.

-- ---------------------------------------------------------------------------
-- POLICY: Parents — SELECT objects in their family path
-- ---------------------------------------------------------------------------
-- Path format: <family_id>/<chore_instance_id>/<filename>
-- We extract the first path component and compare to the JWT's family_id claim.
-- The JWT claim name is 'family_id' set by the app's auth flow (parent login).
CREATE POLICY "parents_select_family_photos"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'proof-photos'
  AND (
    -- Parent/caregiver: family_id claim matches path prefix
    (auth.jwt() ->> 'role') IN ('parent', 'caregiver')
    AND (storage.foldername(name))[1] = (auth.jwt() ->> 'family_id')
  )
);

-- ---------------------------------------------------------------------------
-- POLICY: Children — INSERT objects into their family path
-- ---------------------------------------------------------------------------
CREATE POLICY "kids_insert_family_photos"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'proof-photos'
  AND (auth.jwt() ->> 'role') = 'child'
  -- Child may only upload under their own family_id prefix
  AND (storage.foldername(name))[1] = (auth.jwt() ->> 'family_id')
);

-- ---------------------------------------------------------------------------
-- POLICY: No client DELETE — service_role bypasses RLS for purge
-- ---------------------------------------------------------------------------
-- No DELETE policy is defined for 'authenticated'; service_role skips RLS.
-- This means only the photo.purge-expired edge function (running as
-- service_role) may delete objects, enforced by Postgres's "no matching
-- policy = deny" default when RLS is enabled.

-- ---------------------------------------------------------------------------
-- POLICY: No UPDATE from clients
-- ---------------------------------------------------------------------------
-- No UPDATE policy defined. Objects are write-once from client perspective.



