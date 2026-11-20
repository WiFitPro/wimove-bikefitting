-- =====================================================================
-- WiFitPro · Update 3: Logo und Kontaktdaten für den Bericht je Konto
-- Einmal im SQL Editor ausführen (Run). Mehrfaches Ausführen schadet nicht.
-- Jedes freigeschaltete Konto darf nur seinen eigenen Bereich data/users/<Konto-ID>/… lesen und schreiben.
-- =====================================================================
drop policy if exists "daten lesen (freigeschaltet)" on public.app_docs;
create policy "daten lesen (freigeschaltet)" on public.app_docs for select to authenticated
  using (public.is_approved() and (path not like 'data/users/%' or path like 'data/users/' || auth.uid()::text || '/%'));

drop policy if exists "eigene daten anlegen" on public.app_docs;
create policy "eigene daten anlegen" on public.app_docs for insert to authenticated
  with check (public.is_approved() and path like 'data/users/' || auth.uid()::text || '/%');
drop policy if exists "eigene daten ändern" on public.app_docs;
create policy "eigene daten ändern" on public.app_docs for update to authenticated
  using (public.is_approved() and path like 'data/users/' || auth.uid()::text || '/%')
  with check (public.is_approved() and path like 'data/users/' || auth.uid()::text || '/%');
drop policy if exists "eigene daten löschen" on public.app_docs;
create policy "eigene daten löschen" on public.app_docs for delete to authenticated
  using (public.is_approved() and path like 'data/users/' || auth.uid()::text || '/%');

-- Kontrolle: sollte die Regeln der Tabelle app_docs zeigen
select policyname, cmd from pg_policies where tablename = 'app_docs' order by policyname;
