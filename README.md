# WiFitPro als eigene Web-App – Einrichtung

Inhalt dieses Pakets:
- `supabase-setup.sql` – richtet in Supabase Benutzerrollen, Rechte und deine bisherigen Teile/Räder ein
- `app/` – die fertige App. **Nur diesen Ordner** bei Netlify hochladen.

## 1. Datenbank einrichten (Supabase, einmalig)
1. In Supabase dein Projekt öffnen → links **SQL Editor** → **New query**.
2. Den kompletten Inhalt von `supabase-setup.sql` hineinkopieren → **Run**.
3. Unten sollten 3 Zeilen erscheinen (`settings/access`, `settings/factory`, `settings/library`).

## 2. Anmeldung einstellen (Supabase)
1. **Authentication → Sign In / Providers → Email**: „**Confirm email**“ **ausschalten** → Save.
   Grund: Neue Konten werden ohnehin von dir freigeschaltet. Der kostenlose Supabase-Mailversand
   schickt außerdem nur an Mitglieder deines Supabase-Teams, Bestätigungsmails kämen bei
   Mitarbeitern sonst nicht an.
2. Optional: unter „Password“ eine Mindestlänge von 8 Zeichen einstellen.

## 3. App online stellen (Netlify)
1. Bei https://app.netlify.com anmelden.
2. **Add new project → Deploy manually** und den Ordner **`app`** in das Feld ziehen.
3. **Project configuration → Change project name** → z. B. `wifit-wildrad`.
   Die App ist dann unter `https://wifit-wildrad.netlify.app` erreichbar.

## 4. Adresse in Supabase eintragen
**Authentication → URL Configuration**:
- **Site URL**: deine Netlify-Adresse, z. B. `https://wifit-wildrad.netlify.app`
- **Redirect URLs**: dieselbe Adresse hinzufügen.

## 5. Erstes Konto = Admin
Öffne die App und **registriere dich als Erster**. Das allererste Konto wird automatisch Admin
und ist sofort freigeschaltet. Alle weiteren Konten sind Nutzer und warten auf deine Freischaltung
(Tab **Daten → Benutzerverwaltung**).

## Updates der Datenbank
Neue Funktionen können ein Update-Skript brauchen (`supabase-update-*.sql`). Jedes einmal im SQL Editor ausführen.
- `supabase-update-2-zugang.sql`: Zugang je Konto (WiFitPro + Basic oder nur WiFitBasic)

## Rollen
| | Admin | Nutzer |
|---|---|---|
| WiFitBasic, Fittings, PDF-Reports | ✓ | ✓ |
| WiFitPro | ✓ | wenn unter „Zugang“ freigegeben |
| Teile, Räder und Standardwerte der gemeinsamen Datenbank ändern | ✓ | – |
| Benutzer freischalten, sperren, Rollen vergeben | ✓ | – |

Kundendaten (Person, Befund, Bike Set Up) bleiben auf dem jeweiligen Gerät und werden nicht zentral gespeichert.

## Als App auf iPad, Handy oder Computer
- **iPad/iPhone (Safari):** Teilen-Symbol → „Zum Home-Bildschirm“.
- **Android/Chrome/Edge:** Menü → „App installieren“.

## Updates
Neue Fassung: in Netlify unter **Deploys** den neuen Ordner `app` in das Feld ziehen.
Daten und Konten bleiben dabei erhalten.

## Passwort vergessen
Ohne eigenen Mailversand kommen Mails zum Zurücksetzen bei Mitarbeitern nicht an. Dann in Supabase
unter **Authentication → Users** das Konto löschen; die Person registriert sich neu und du schaltest sie frei.
Dauerhafte Lösung: unter **Project Settings → Authentication → SMTP** euren Mail-Server eintragen.

## Sicherheit
- `config.js` enthält nur die öffentliche Projekt-Adresse und den öffentlichen Schlüssel – das ist so vorgesehen.
- Den **secret / service_role key** und das **Datenbank-Passwort** nie in die App oder an andere weitergeben.
