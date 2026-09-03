-- Upsert needs SELECT as well as the existing INSERT/UPDATE policies.
-- Only the signed-in user's own avatar folder is visible through this policy.
create policy "read own avatar" on storage.objects
for select to authenticated
using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
