-- =====================================================================
-- HomeConnect Admin Panel — ตั้งค่าฐานข้อมูลสำหรับเว็บแอดมิน
-- รันใน Supabase › SQL Editor ครั้งเดียว (รันซ้ำได้ ไม่พัง)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) สิทธิ์: user (ลูกค้า) / admin (แอดมิน) / owner (ผู้ดูแลหลัก)
-- ---------------------------------------------------------------------
alter table public.profiles alter column role set default 'user';
update public.profiles set role = 'user' where role is null;

-- เก็บอีเมลไว้ใน profiles ด้วย (แอดมินต้องเห็นอีเมลผู้ใช้ / เพิ่มแอดมินด้วยอีเมล)
alter table public.profiles add column if not exists email text;
update public.profiles p
   set email = u.email
  from auth.users u
 where u.id = p.id and p.email is distinct from u.email;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path to ''
as $$
begin
  insert into public.profiles (id, full_name, phone, email)
  values (new.id,
          new.raw_user_meta_data->>'full_name',
          new.raw_user_meta_data->>'phone',
          new.email);
  return new;
end $$;

-- อีเมลใน auth เปลี่ยน → อัปเดต profiles ตาม
create or replace function public.sync_profile_email()
returns trigger
language plpgsql
security definer
set search_path to ''
as $$
begin
  update public.profiles set email = new.email where id = new.id;
  return new;
end $$;

drop trigger if exists on_auth_user_email_changed on auth.users;
create trigger on_auth_user_email_changed
  after update of email on auth.users
  for each row execute function public.sync_profile_email();

-- แอดมิน = admin หรือ owner
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select exists (
    select 1 from public.profiles
     where id = auth.uid() and role in ('admin', 'owner')
  );
$$;

create or replace function public.is_owner()
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select exists (
    select 1 from public.profiles
     where id = auth.uid() and role = 'owner'
  );
$$;

-- ---------------------------------------------------------------------
-- 2) แก้ช่องโหว่: ผู้ใช้แก้ role / email / id ของตัวเองผ่าน API ไม่ได้
--    (เดิม profiles_update_own ยอมให้แก้ทุกคอลัมน์ → ตั้งตัวเองเป็น admin ได้)
--    การเปลี่ยน role ต้องผ่านฟังก์ชัน set_admin_role ด้านล่างเท่านั้น
-- ---------------------------------------------------------------------
create or replace function public.protect_profile_columns()
returns trigger
language plpgsql
set search_path to ''
as $$
begin
  -- current_user = 'authenticated' / 'anon' คือคำสั่งที่มาจากแอปหรือเว็บโดยตรง
  -- (ฟังก์ชัน security definer และ trigger ของระบบรันเป็น postgres จึงผ่านได้)
  if current_user in ('authenticated', 'anon') and (
       new.role  is distinct from old.role
    or new.email is distinct from old.email
    or new.id    is distinct from old.id
  ) then
    raise exception 'ไม่มีสิทธิ์แก้ไขสิทธิ์ผู้ใช้หรืออีเมลโดยตรง';
  end if;
  return new;
end $$;

drop trigger if exists protect_profile_columns on public.profiles;
create trigger protect_profile_columns
  before update on public.profiles
  for each row execute function public.protect_profile_columns();

-- ---------------------------------------------------------------------
-- 3) ผู้ดูแลหลักเพิ่ม / เปลี่ยนสิทธิ์ / ถอดสิทธิ์แอดมิน (ด้วยอีเมล)
-- ---------------------------------------------------------------------
create or replace function public.set_admin_role(p_email text, p_role text)
returns void
language plpgsql
security definer
set search_path to ''
as $$
declare
  target uuid;
  target_role text;
begin
  if not public.is_owner() then
    raise exception 'เฉพาะผู้ดูแลหลักเท่านั้นที่ทำรายการนี้ได้';
  end if;
  if p_role not in ('owner', 'admin', 'user') then
    raise exception 'สิทธิ์ไม่ถูกต้อง';
  end if;

  select id, role into target, target_role
    from public.profiles
   where lower(email) = lower(trim(p_email));
  if target is null then
    raise exception 'ไม่พบบัญชีอีเมลนี้ — ให้คนนั้นสมัครสมาชิกก่อน';
  end if;
  if target = auth.uid() then
    raise exception 'เปลี่ยนสิทธิ์ของตัวเองไม่ได้';
  end if;
  -- ต้องเหลือผู้ดูแลหลักอย่างน้อย 1 คน
  if target_role = 'owner' and p_role <> 'owner' and (
    select count(*) from public.profiles where role = 'owner'
  ) <= 1 then
    raise exception 'ต้องมีผู้ดูแลหลักอย่างน้อย 1 คน';
  end if;

  update public.profiles set role = p_role where id = target;
end $$;

revoke all on function public.set_admin_role(text, text) from public, anon;
grant execute on function public.set_admin_role(text, text) to authenticated;

-- ---------------------------------------------------------------------
-- 4) แอดมินอ่านการกดใจทั้งหมดได้ (รายงาน "ความสนใจ")
-- ---------------------------------------------------------------------
drop policy if exists favorites_admin_read on public.favorites;
create policy favorites_admin_read on public.favorites
  for select using (public.is_admin());

-- ---------------------------------------------------------------------
-- 5) แขวง/ตำบล (เว็บแอดมินมีช่องนี้)
-- ---------------------------------------------------------------------
alter table public.projects add column if not exists sub_district text;

-- ---------------------------------------------------------------------
-- 6) ผู้ดูแลหลักคนแรก — แก้อีเมลเป็นของคุณ แล้วรันบรรทัดนี้
--    (ต้องสร้างบัญชีก่อน: Authentication › Users › Add user)
-- ---------------------------------------------------------------------
-- update public.profiles set role = 'owner' where email = 'อีเมลของคุณ@example.com';
