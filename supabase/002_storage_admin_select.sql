-- =====================================================================
-- ให้แอดมินลบ/แทนที่รูปโครงการใน Storage ได้
-- (Supabase ต้องมีสิทธิ์ SELECT ด้วย ถึงจะลบไฟล์ได้ — เดิมมีแค่ insert/update/delete)
-- รันใน Supabase › SQL Editor ครั้งเดียว (รันซ้ำได้)
-- =====================================================================
drop policy if exists admin_select on storage.objects;
create policy admin_select on storage.objects
  for select to authenticated
  using (bucket_id = 'project-images' and public.is_admin());
