# mySumber

Flutter mobile app for Malaysian water and electricity anomaly monitoring.
It supports three roles: **Admin**, **Worker**, and **Customer**, and uses
government reference data together with Supabase operational data.

## Main functions

| Area | What it does | Data source |
|---|---|---|
| Admin inventory | Equipment catalogue, deployment, health, CSV import preview and confirmation | Supabase + local CSV references |
| Admin oversight | Abnormal production, alerts, reports, worker accounts and AI anomaly review | Supabase + local CSV references |
| Worker | Water and electricity alert queues, investigation and field reports | Supabase + local CSV references |
| Customer | Household usage comparison, notifications and problem reporting | Supabase + local CSV references |

## Authentication and access

All users sign in through Supabase Auth. The app resolves an authenticated
user's active role from the `profiles` table:

- **Admin:** inventory, oversight, AI review and worker accounts.
- **Worker:** water and electricity alert workflows.
- **Customer:** personal usage and reporting.

Do not add passwords, a Supabase `service_role` key, or an AI-provider key to
the Flutter app.

## AI anomaly review

When an active Admin chooses **Generate AI Analysis**, the Flutter app sends
only the selected alert ID to the `generate-anomaly-analysis` Supabase Edge
Function. The function verifies the caller's profile, fetches the alert,
calls Groq server-side, validates the response, and saves the result to the
same alert. The client never contains a Groq credential.

Before deploying this feature, the project owner must rotate any previously
used Groq key and configure its replacement as a Supabase secret:

```bash
npx supabase login
npx supabase link --project-ref tnmznkdvrrpigevxdfet
npx supabase db push
npx supabase secrets set GROQ_API_KEY="your-rotated-key"
npx supabase functions deploy generate-anomaly-analysis
```

The function requires `GROQ_API_KEY`; Supabase supplies the other required
environment variables at runtime. Do not put this key in `lib/` or commit it.

## Equipment CSV import

Use [docs/equipment-import-template.csv](docs/equipment-import-template.csv)
as the starting format. The importer always shows a preview with valid, new,
updated and skipped rows before it writes anything. `asset_tag` is the stable
equipment identity; facility, model, manufacturer and firmware values must
already exist in the Admin catalogue.

For IP data, use `Static` with a valid IPv4/IPv6 address, or use `DHCP` / `Not
Assigned` and leave `ip_address` empty.

## Project structure

```text
lib/
  main.dart                         App entry point and role navigation
  modules/
    auth/                           Sign in and registration
    admin/                          Admin dashboard, oversight and AI review
    dataset/                        Inventory, catalogue and CSV import
    leakage/                        Worker alert and report workflows
    usage/                          Customer usage and reporting
  theme/                            Shared design tokens
supabase/
  migrations/                       Database schema and RLS policies
  functions/generate-anomaly-analysis/  Server-only AI analysis function
assets/                             Read-only government CSV references
test/                               Widget, logic and security regression tests
```

## Local setup

```bash
git clone <repo-url>
cd Mobile-Assignmnet
flutter pub get
flutter test
flutter analyze
flutter run
```

The public Supabase configuration in `lib/main.dart` is sufficient for normal
app use. Database migrations and the AI Edge Function must be deployed by a
project owner before testing the cloud-backed inventory or AI features.

## Pre-publish checklist

- [ ] `flutter test` passes
- [ ] `flutter analyze` has no findings
- [ ] Debug and release APK builds complete
- [ ] Supabase migrations are applied to the production project
- [ ] `generate-anomaly-analysis` is deployed
- [ ] A newly rotated `GROQ_API_KEY` is stored only in Supabase secrets
- [ ] Android application ID and release signing are configured
- [ ] No private credentials are committed
