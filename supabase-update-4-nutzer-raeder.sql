-- =====================================================================
-- WiFitPro · Update 4: Nutzer dürfen Räder hinzufügen (nicht ändern, nicht löschen)
-- Einmal im SQL Editor ausführen (Run). Mehrfaches Ausführen schadet nicht.
-- Neue Räder von Nutzern landen in einer eigenen Tabelle. Alle Freigeschalteten sehen sie,
-- jeder Freigeschaltete darf neue Zeilen anlegen, ändern und löschen dürfen nur Admins.
-- =====================================================================
create table if not exists public.user_bikes (
  id          bigint generated always as identity primary key,
  marke       text not null default '',
  modell      text not null default '',
  grosse      text not null default '',
  data        jsonb not null,
  created_by  uuid not null default auth.uid() references auth.users(id) on delete set null,
  created_at  timestamptz not null default now()
);
alter table public.user_bikes alter column created_by drop not null;
alter table public.user_bikes enable row level security;

drop policy if exists "räder lesen (freigeschaltet)" on public.user_bikes;
create policy "räder lesen (freigeschaltet)" on public.user_bikes for select to authenticated
  using (public.is_approved());
drop policy if exists "räder anlegen (freigeschaltet)" on public.user_bikes;
create policy "räder anlegen (freigeschaltet)" on public.user_bikes for insert to authenticated
  with check (public.is_approved() and created_by = auth.uid());
drop policy if exists "räder ändern (admin)" on public.user_bikes;
create policy "räder ändern (admin)" on public.user_bikes for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
drop policy if exists "räder löschen (admin)" on public.user_bikes;
create policy "räder löschen (admin)" on public.user_bikes for delete to authenticated
  using (public.is_admin());

revoke all on public.user_bikes from anon;
grant select, insert, update, delete on public.user_bikes to authenticated;

-- Kontrolle: Tabelle und Regeln
select policyname, cmd from pg_policies where tablename = 'user_bikes' order by policyname;
