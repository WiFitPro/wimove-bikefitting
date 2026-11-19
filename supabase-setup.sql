-- =====================================================================
-- WiFitPro · Einrichtung der Datenbank in Supabase
-- Einmal komplett im SQL Editor ausführen (Run). Mehrfaches Ausführen schadet nicht.
-- =====================================================================

-- 1) Benutzerprofile: Rolle (admin / user) und Freischaltung
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  email       text,
  full_name   text default '',
  role        text not null default 'user' check (role in ('admin','user')),
  approved    boolean not null default false,
  access      text not null default 'basic' check (access in ('pro','basic')),   -- 'pro' = WiFitPro + Basic, 'basic' = nur WiFitBasic
  created_at  timestamptz not null default now()
);
alter table public.profiles enable row level security;

-- Hilfsfunktionen: ist der angemeldete Nutzer freigeschaltet bzw. Admin?
create or replace function public.is_approved() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and approved);
$$;
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and approved and role = 'admin');
$$;
revoke all on function public.is_approved() from public, anon;
revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_approved() to authenticated;
grant execute on function public.is_admin() to authenticated;

-- Neues Konto → Profil anlegen. Das allererste Konto wird automatisch freigeschalteter Admin,
-- alle weiteren sind Nutzer und warten auf Freischaltung durch einen Admin.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare first_admin boolean;
begin
  select not exists (select 1 from public.profiles where role = 'admin') into first_admin;
  insert into public.profiles (id, email, full_name, role, approved, access)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name', ''),
          case when first_admin then 'admin' else 'user' end, first_admin,
          case when first_admin then 'pro' else 'basic' end)
  on conflict (id) do nothing;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Schutz: es muss immer mindestens ein freigeschalteter Admin bleiben; E-Mail und ID sind nicht änderbar
create or replace function public.guard_profiles() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.id <> old.id or coalesce(new.email,'') <> coalesce(old.email,'') then
    raise exception 'ID und E-Mail können hier nicht geändert werden';
  end if;
  if old.role = 'admin' and old.approved and (new.role <> 'admin' or not new.approved)
     and not exists (select 1 from public.profiles where role = 'admin' and approved and id <> old.id) then
    raise exception 'Es muss mindestens ein freigeschalteter Admin bleiben';
  end if;
  return new;
end $$;
drop trigger if exists profiles_guard on public.profiles;
create trigger profiles_guard before update on public.profiles
  for each row execute function public.guard_profiles();

-- Zugriffsregeln Profile: jeder sieht sein eigenes, Admins sehen und ändern alle
drop policy if exists "profil lesen" on public.profiles;
create policy "profil lesen" on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_admin());
drop policy if exists "profil ändern (admin)" on public.profiles;
create policy "profil ändern (admin)" on public.profiles for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
revoke all on public.profiles from anon;
grant select, update (full_name, role, approved, access) on public.profiles to authenticated;

-- 2) Gemeinsame App-Daten (eigene Teile, Räder, Standardwerte, WiFitPro-Passwort)
create table if not exists public.app_docs (
  path        text primary key,
  data        jsonb not null,
  updated_at  timestamptz not null default now(),
  updated_by  uuid default auth.uid()
);
alter table public.app_docs enable row level security;
drop policy if exists "daten lesen (freigeschaltet)" on public.app_docs;
create policy "daten lesen (freigeschaltet)" on public.app_docs for select to authenticated
  using (public.is_approved());
drop policy if exists "daten anlegen (admin)" on public.app_docs;
create policy "daten anlegen (admin)" on public.app_docs for insert to authenticated
  with check (public.is_admin());
drop policy if exists "daten ändern (admin)" on public.app_docs;
create policy "daten ändern (admin)" on public.app_docs for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
drop policy if exists "daten löschen (admin)" on public.app_docs;
create policy "daten löschen (admin)" on public.app_docs for delete to authenticated
  using (public.is_admin());
revoke all on public.app_docs from anon;
grant select, insert, update, delete on public.app_docs to authenticated;

-- 3) Startdaten: deine bisherigen eigenen Teile, Räder und Standardwerte aus der Claude-Version
--    (vorhandene Einträge werden nicht überschrieben)
insert into public.app_docs (path, data) values
  ('settings/library', $wf${"at": 1794916483875, "data": {"bikeDel": [], "bikeFix": {}, "bikeRename": {}, "customBikes": [{"grosse": "XS", "kettenstrebe": 405, "marke": "Megamo", "modell": "Raise (2023)", "oberrohr": 507, "reach": 357, "sitzrohr": 422, "sitzwinkel": 73.5, "stack": 505, "steuerrohr": 103, "steuerwinkel": 70.5, "tretlageroffset": 66}, {"grosse": "S", "kettenstrebe": 405, "marke": "Megamo", "modell": "Raise (2023)", "oberrohr": 523, "reach": 369, "sitzrohr": 453, "sitzwinkel": 73.5, "stack": 522, "steuerrohr": 116, "steuerwinkel": 72, "tretlageroffset": 66}, {"grosse": "M", "kettenstrebe": 405, "marke": "Megamo", "modell": "Raise (2023)", "oberrohr": 541, "reach": 381, "sitzrohr": 473, "sitzwinkel": 73.5, "stack": 541, "steuerrohr": 135, "steuerwinkel": 72, "tretlageroffset": 66}, {"grosse": "L", "kettenstrebe": 405, "marke": "Megamo", "modell": "Raise (2023)", "oberrohr": 559, "reach": 393, "sitzrohr": 499, "sitzwinkel": 73.5, "stack": 560, "steuerrohr": 156, "steuerwinkel": 72, "tretlageroffset": 66}, {"grosse": "XL", "kettenstrebe": 405, "marke": "Megamo", "modell": "Raise (2023)", "oberrohr": 576, "reach": 405, "sitzrohr": 525, "sitzwinkel": 73.5, "stack": 580, "steuerrohr": 176, "steuerwinkel": 72, "tretlageroffset": 66}, {"grosse": "45", "kettenstrebe": 400, "marke": "Basso", "modell": "Diamante (2022)", "oberrohr": 505, "reach": 374.9, "sitzrohr": 450, "sitzwinkel": 76, "stack": 521.7, "steuerrohr": 101, "steuerwinkel": 71.3}, {"grosse": "48", "kettenstrebe": 400, "marke": "Basso", "modell": "Diamante (2022)", "oberrohr": 515, "reach": 375.2, "sitzrohr": 480, "sitzwinkel": 75, "stack": 521.8, "steuerrohr": 101, "steuerwinkel": 71.4}, {"grosse": "51", "kettenstrebe": 400, "marke": "Basso", "modell": "Diamante (2022)", "oberrohr": 525, "reach": 378.6, "sitzrohr": 510, "sitzwinkel": 75, "stack": 546.2, "steuerrohr": 126, "steuerwinkel": 71.6}, {"grosse": "53", "kettenstrebe": 400, "marke": "Basso", "modell": "Diamante (2022)", "oberrohr": 545, "reach": 384.8, "sitzrohr": 530, "sitzwinkel": 74, "stack": 558.8, "steuerrohr": 138, "steuerwinkel": 71.9}, {"grosse": "56", "kettenstrebe": 402, "marke": "Basso", "modell": "Diamante (2022)", "oberrohr": 560, "reach": 386.9, "sitzrohr": 560, "sitzwinkel": 73.5, "stack": 584.3, "steuerrohr": 155, "steuerwinkel": 73.1}, {"grosse": "58", "kettenstrebe": 402, "marke": "Basso", "modell": "Diamante (2022)", "oberrohr": 575, "reach": 389, "sitzrohr": 580, "sitzwinkel": 73, "stack": 608, "steuerrohr": 180, "steuerwinkel": 73.1}, {"grosse": "61", "kettenstrebe": 406, "marke": "Basso", "modell": "Diamante (2022)", "oberrohr": 590, "reach": 390.7, "sitzrohr": 610, "sitzwinkel": 72.5, "stack": 632.2, "steuerrohr": 203, "steuerwinkel": 73.6}, {"grosse": "XS", "kettenstrebe": 430, "marke": "Megamo", "modell": "West (2027)", "oberrohr": 530, "radstand": 1031, "reach": 378, "sitzwinkel": 74.5, "stack": 548, "steuerrohr": 120, "steuerwinkel": 69.5}, {"grosse": "S", "kettenstrebe": 430, "marke": "Megamo", "modell": "West (2027)", "oberrohr": 550, "radstand": 1047, "reach": 391, "sitzwinkel": 74.25, "stack": 563, "steuerrohr": 135, "steuerwinkel": 69.75}, {"grosse": "M", "kettenstrebe": 430, "marke": "Megamo", "modell": "West (2027)", "oberrohr": 565, "radstand": 1059, "reach": 400, "sitzwinkel": 74, "stack": 576, "steuerrohr": 150, "steuerwinkel": 70}, {"grosse": "L", "kettenstrebe": 430, "marke": "Megamo", "modell": "West (2027)", "oberrohr": 580, "radstand": 1070, "reach": 405, "sitzwinkel": 73.75, "stack": 600, "steuerrohr": 175, "steuerwinkel": 70.25}, {"grosse": "XL", "kettenstrebe": 430, "marke": "Megamo", "modell": "West (2027)", "oberrohr": 600, "radstand": 1086, "reach": 415, "sitzwinkel": 73.5, "stack": 625, "steuerrohr": 200, "steuerwinkel": 70.5}], "customParts": {"bars": [{"angle": 0, "height": 28, "name": "Colnago Y1RS Cockpit", "reach": 55}, {"angle": -8, "height": 42, "name": "Megamo Carbon Gravel", "reach": 45}, {"angle": -8, "height": 34, "name": "Megamo Carbon Gravel Racing", "reach": 55}, {"angle": -8, "height": 34, "name": "Megamo Carbon Road", "reach": 60}], "stems": [{"angle": 8, "height": 39, "name": "LevelNine"}]}, "partDel": [], "partFix": {"bars": {"BMC ICS Aero Cockpit": {"angle": -8}, "Basso Fuga": {"angle": -8, "height": 30}, "Basso Levita": {"angle": -8, "height": 30, "reach": 40}, "Basso Microtech": {"height": 35}, "Bianci Specialissima": {"angle": -8}, "Canyon CP0018": {"angle": -8, "reach": 55}, "Canyon CP0030": {"angle": -8}, "Canyon CP0048": {"angle": -6, "height": 45}, "Cervelo R5 HB18": {"angle": -6, "height": 35, "reach": 60}, "Cervelo S5 HB19": {"angle": -6, "reach": 60}, "Cube ICR Cockpit": {"height": 42}, "Megamo Pulse": {"angle": -10, "height": 28, "reach": 50}, "Newmen Road": {"reach": 60}, "Pro Vibe": {"reach": 55}, "Rose": {"height": null, "reach": 65}, "Roval Rapide Cockpit": {"reach": 60}, "Standard": {"reach": 65}, "Talon Ultra Fast": {"angle": -8}, "Talon Ultra Light": {"angle": -8}}, "levers": {"Shimano 105 Di2": {"reach": 50}, "Shimano Dura-Ace Di2": {"reach": 50}, "Shimano Dura-Ace Di2 11-fach": {"reach": 50}, "Shimano GRX Di2": {"reach": 50}, "Shimano GRX Di2 11-fach": {"reach": 50}, "Shimano Ultegra Di2": {"reach": 50}, "Shimano Ultegra Di2 11-fach": {"reach": 50}, "Sram Force 22 mech.": {"reach": 55}, "Sram Force E1": {"reach": 55}, "Sram Red 22 mech.": {"reach": 55}, "Sram Red E1": {"reach": 55}, "Sram Rival 22 mech.": {"reach": 55}, "Sram Rival E1": {"reach": 55}}, "stems": {"S-Works": {"angle": -8, "height": 38}}}, "partRename": {}}}$wf$::jsonb),
  ('settings/factory', $wf${"at": 1794934024326, "vals": {"ankleH": 78, "armAdd": 70, "cleat": 70, "elbowT": 162, "footAngle": 25, "hipFwd": 35, "hipStand": 45, "kneeBack": 0, "protr": 30, "shoulderDrop": 35, "sink": 18, "sitBack": 40, "styleStd": {"ambitioniert": {"back": 43.5, "shoulder": 79}, "comfort": {"back": 50, "shoulder": 74.5}, "endurance": {"back": 47.5, "shoulder": 76}, "professional": {"back": 40, "shoulder": 80.5}, "sportlich": {"back": 45, "shoulder": 77.5}}}}$wf$::jsonb),
  ('settings/access',  $wf${"at": 1794389182997, "hash": "340dd28ce4e291fd0b96e4f62e42f49a25ab69d28fa5a847a963ce59526f8661"}$wf$::jsonb)
on conflict (path) do nothing;

-- Fertig. Kontrolle: sollte 3 Zeilen zeigen
select path, updated_at from public.app_docs order by path;
