-- =====================================================================
-- WiFitPro · Update 2: Zugang je Konto (WiFitPro + Basic oder nur WiFitBasic)
-- Einmal im SQL Editor ausführen (Run). Mehrfaches Ausführen schadet nicht.
-- =====================================================================
alter table public.profiles add column if not exists access text not null default 'basic';
alter table public.profiles drop constraint if exists profiles_access_check;
alter table public.profiles add constraint profiles_access_check check (access in ('pro','basic'));
-- bereits freigeschaltete Konten behalten vollen Zugang
update public.profiles set access = 'pro' where approved and access <> 'pro';
-- Admins dürfen den Zugang ändern
grant update (full_name, role, approved, access) on public.profiles to authenticated;
-- Kontrolle
select email, role, approved, access from public.profiles order by created_at;
