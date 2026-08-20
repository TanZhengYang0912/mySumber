# MySumber Project Documentation

## Overview

**MySumber** is a Flutter mobile app for water & electricity anomaly detection using Malaysian government open data (data.gov.my). The app supports SDG 9 (Industry, Innovation, and Infrastructure).

- **Team:** BMIT2073 Mobile Application Development assignment
- **Platform:** Android & iOS (Flutter)
- **Cloud:** Supabase (PostgreSQL)
- **Status:** 4 modules, all active. Restructured into a 3-role system (Admin / Worker / Customer) with a dedicated `modules/admin` folder; Module 2 (Personal Usage) is now fully built out (no longer a placeholder); Module 4 (Electricity) was merged/mirrored into `modules/admin` and `modules/leakage` rather than staying standalone.

---

## Working With Claude Code

**Never edit code on the first ask.** For any change request (bug fix, UI tweak, refactor):
1. **Discuss** — talk through the problem/approach in chat. Do not write a plan yet.
2. **Plan** — only after the user approves the discussion, write the implementation plan.
3. **Edit** — only after the user approves the plan, make the code changes.

Do not skip straight to editing files just because the intent seems clear — confirm at each step first.

---

## Architecture Overview

### Frontend
- **Framework:** Flutter 3.12+ (Dart)
- **State Management:** Provider (ChangeNotifier)
- **UI:** Material Design 3
- **Charts:** fl_chart 1.2.0

### Backend (Cloud)
- **Provider:** Supabase (managed Postgres)
- **URL:** `https://tnmznkdvrrpigevxdfet.supabase.co`
- **Auth:** Anonymous (public key embedded in code)
- **Tables:** `alerts`, `readings`, `reports` (Module 3 only)

### Data Sources
- **Local:** 4 bundled CSV files (government datasets, read-only)
  - `water_consumption.csv`
  - `water_production.csv`
  - `electricity_consumption.csv`
  - `electricity_supply.csv`
- **Cloud:** Supabase, polled every 10s (Module 3)

---

## Project Structure

```
lib/
├── main.dart                          SHARED (entry point, MySumberApp, role-based AppShell, providers)
├── theme/
│   └── tokens.dart                    Shared AppColors + role/utility color helpers (Figma design tokens)
└── modules/
    ├── auth/                          Module 0: Landing + role-aware login/register
    │   ├── screens/
    │   │   ├── landing_screen.dart        3 role buttons (Admin/Worker/Customer)
    │   │   ├── login_screen.dart          Single login screen, themed per role
    │   │   └── register_screen.dart       Customer sign-up only
    │   └── state/
    │       └── auth_state.dart            RoleState (Supabase auth + hardcoded email→role map)
    │
    ├── admin/                         Admin-only screens (new role surface)
    │   └── screens/
    │       ├── abnormal_production_screen.dart   Renders as "Anomalies" — State | Mall tabs, water/electricity chips
    │       ├── admin_alert_detail_screen.dart    Includes AiAnalysisCard (shared with Worker's detail screen)
    │       └── oversight_screen.dart
    │
    ├── dataset/                       Module 1: Equipment Management (admin)
    │   ├── data/                      CSV parsing & dataset repository
    │   ├── models/                    Dataset, Node, Equipment classes
    │   ├── screens/                   Dashboard, inventory, detail screens
    │   ├── services/                  Anomaly detection
    │   └── state/                     DatasetState (Provider)
    │
    ├── usage/                         Module 2: Personal Usage Comparison (customer) — now fully built
    │   ├── screens/
    │   │   ├── customer_home_screen.dart
    │   │   ├── compare_usage_screen.dart
    │   │   ├── my_reports_screen.dart
    │   │   ├── notifications_screen.dart
    │   │   └── report_problem_screen.dart
    │   └── services/
    │       └── electricity_baseline_service.dart
    │
    └── leakage/                       Module 3: Water Leakage Detection (worker) — also carries electricity loss logic
        ├── data/                      LeakageRepository (Supabase CRUD)
        ├── models/                    Alert, Reading, Report, AiAnomalyAnalysis
        ├── screens/                   Home, alert queue/detail/evidence, reports
        ├── services/                  Detection, baseline, explainer, NRW, simulation, electricity_loss_service
        └── state/                     AppState (Provider)

assets/
├── water_consumption.csv              Government reference data
├── water_production.csv
├── electricity_consumption.csv
└── electricity_supply.csv
```

> Note: standalone `modules/electricity` (Module 4) screens/state were removed — electricity anomaly detection is now folded into `modules/admin` (oversight/abnormal production) and `modules/leakage` (electricity_loss_service), rather than a separate dashboard.

---

## Module Breakdown

| Module | Owner | Purpose | Storage | Status |
|--------|-------|---------|---------|--------|
| 0. Auth | Assigned | Landing + role-based login (Admin/Worker/Customer) | Supabase auth | ✅ Complete |
| Admin | Chun Jie Tan | Oversight, Anomalies (State + Mall detection) | Local CSV + Supabase | ✅ Active |
| 1. Equipment | Chun Jie Tan | Dataset management & state variance | Local CSV | ✅ Active |
| 2. Comparison | Unassigned | Household vs. state usage, reports, notifications | Local CSV | ✅ Active (built out) |
| 3. Leakage | Worker X | Water anomaly detection + electricity loss | Supabase + CSV | ✅ Active |

> Module 4 (Electricity) no longer exists as a standalone module — its logic was merged into Admin (`abnormal_production_screen.dart`, `oversight_screen.dart`) and Leakage (`electricity_loss_service.dart`).
>
> There is no standalone "AI Review" page — it was removed. AI now appears in two places: an ephemeral preview (nothing persisted) while Admin is deciding whether to forward a State/Mall anomaly in the Anomalies screen, and a persisted `AiAnalysisCard` on the actual alert once it exists — shown on both Worker's and Admin's alert detail screens, auto-populated a few seconds after creation by a database trigger (see "AI Summaries (Groq)" below).

---

## Tech Stack

### Dependencies
```yaml
flutter: sdk (3.12.2+)
provider: ^6.1.5          # State management
csv: ^6.0.0               # CSV parsing
fl_chart: ^1.2.0          # Charts
supabase_flutter: ^2.9.0  # Cloud backend
intl: ^0.20.2             # Date/number formatting
uuid: ^4.5.3              # Unique IDs
lucide_icons: ^0.257.0    # Icon set (Figma parity)
http: ^1.2.0              # Address lookup (customer usage module)
```

### AI Summaries (Groq)
`supabase/functions/generate-anomaly-analysis` calls the Groq API server-side. The key is stored as a Supabase function secret (`GROQ_API_KEY`), never in the app. A Postgres trigger fires the function automatically when a new alert is inserted; the app also has a manual "Generate AI Analysis" button as a fallback. The app picks up the result by polling every 10 seconds — this is polling, not Supabase realtime (the project has no realtime subscriptions configured).

### Development
```yaml
flutter_test: sdk
flutter_lints: ^6.0.0
```

---

## Setup & Running

### Prerequisites
- **Flutter SDK 3.12+** installed and in PATH
- **Android Studio** with Android emulator configured
- **Git** for version control

### First-Time Setup

1. **Clone the repo** (if not already done)
   ```bash
   git clone <repo-url>
   cd Mobile-Assignmnet
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Start the Android emulator**
   - Open Android Studio → Device Manager
   - Click **▶️** to start an emulator
   - Wait ~30 seconds for it to fully boot

4. **Verify emulator is ready**
   ```bash
   flutter devices
   ```
   Should show: `emulator-5554 • Android 14 • android-x86_64 • emulator`

### Running the App

```bash
flutter run
```

**First run:** 3-10 minutes (downloads SDKs, builds APK)  
**Subsequent runs:** 30-60 seconds (cached build)

The app will launch on the emulator automatically.

### Hot Reload (Development Loop)

While `flutter run` is active, press **`r`** in the terminal to hot-reload code changes. Much faster than full rebuild (~2 seconds).

---

## Data Flow

### Example: Module 3 (Water Leakage Detection)

```
User creates a reading on phone
    ↓
LeakageRepository.insertReading()
    ↓
Supabase stores in 'readings' table
    ↓
Detection engine analyzes vs. baseline
    ↓
If anomaly → Alert created & stored in 'alerts'
    ↓
Explainer generates human-readable explanation
    ↓
Provider notifies UI listeners
    ↓
All connected phones see the new alert within ~10s (client polls `refresh()` on a timer — there are no Supabase realtime subscriptions in this app)
```

### Equipment Usage Auto-Classification (Admin Inventory)

```
Admin inserts or updates the latest equipment usage reading
    ↓
PostgreSQL calculates the baseline from the previous 7 normal readings
    ↓
Reading becomes Active (<1.25×), Warning (1.25×–<1.50×), or Critical (≥1.50×)
    ↓
equipment_usage_logs.is_anomaly and equipment_nodes.status are updated
    ↓
The status change does not create an alert
```

`Maintenance` is an operator-controlled status and is never overwritten by
automatic classification. An alert exists only when an Admin explicitly
reports or forwards an anomaly; that separate alert can then receive an AI
summary through the `alerts_ai_analysis` trigger.

### Modules 1, 2, 4 (Local Only)

No cloud dependency. All data processed locally; findings stored in Provider state.

---

## Module 0: Authentication System

### Initial Screen: Landing (role picker)
```
┌────────────────────────────────────┐
│          mySumber                   │
│  Utility Management Platform        │
│                                     │
│  [Continue as Admin]                │
│  [Continue as Worker]               │
│  [Continue as Customer]             │
└────────────────────────────────────┘
```
Each button forwards to a single shared `LoginScreen`, themed by role color and (for admin/worker) prefilled with the known staff email.

### Login (all roles, one screen)
There is **no separate admin password path anymore**. Every role — including admin and worker — authenticates through Supabase email + password (`RoleState.login`). Role is then resolved client-side from a hardcoded email lookup in `lib/modules/auth/state/auth_state.dart`:
```dart
const _staffRoles = {
  'admin@mysumber.my': 'admin',
  'worker@mysumber.my': 'worker',
};
// any other authenticated email resolves to 'user' (customer)
```
This means the Supabase project must actually contain accounts for `admin@mysumber.my` and `worker@mysumber.my` for those roles to work — there is no local/offline admin bypass.

### Customer Registration
1. Email + Password (min 8 characters) + confirm password + agree to terms (`register_screen.dart`)
2. Submit → Supabase `signUp`, then immediate `signInWithPassword` → role resolves to `user` → auto-login into customer dashboard
3. Accessible only from the Customer login screen ("Sign Up" link) — admin/worker screens have no registration option

**Role access after login (`AppShell` in `main.dart`):**
- **Admin:** Dashboard, Inventory, Anomalies (State + Mall detection), Oversight, Workers
- **Worker:** Home Screen (Water), Home Screen (Electricity) — both backed by `modules/leakage`
- **Customer (`user`):** Customer Home, Compare Usage, Report Problem

### Error Handling
- Supabase auth errors (bad credentials, unregistered email, etc.) surface via `RoleState.errorMessage`
- Weak password: Shows error (< 8 characters) — checked client-side before submit in `register_screen.dart`
- Passwords must match on registration
- Invalid email format: Validated before submission

### State Management
```dart
RoleState (Provider) — lib/modules/auth/state/auth_state.dart
├── _userRole: "admin" | "worker" | "user" | null   (resolved from email, not stored separately)
├── _email: String?
├── isLoggedIn: bool
├── isLoading: bool
├── errorMessage: String?
├── login(email, password): Future<bool>
├── register(email, password): Future<bool>
├── checkExistingSession(): Future<void>   (checks Supabase session on app start)
└── logout(): Future<void>
```

**Persistence:** Supabase manages the session for all roles (persists until logout), including admin/worker — this is a change from the old local-only admin session.

---

## Module 2: Personal Usage Comparison

**Current status:** Fully built (no longer the placeholder screen). Lives under `lib/modules/usage/` and is the customer-role tab set in `AppShell`:
- `customer_home_screen.dart` — customer landing/dashboard
- `compare_usage_screen.dart` — household vs. state usage comparison
- `my_reports_screen.dart` — customer's submitted reports history
- `notifications_screen.dart` — customer notifications
- `report_problem_screen.dart` — submit a new report (leakage/anomaly)
- `services/electricity_baseline_service.dart` — baseline calc reused for the comparison view

`work_in_progress_screen.dart` was removed entirely.

---

## Important Rules & Constraints

### 🚫 Don't Do This

1. **Rewrite CSV files at runtime** — Assets are read-only reference data
2. **Edit another person's module folder** — Each person owns one module
3. **Commit a Supabase `service_role` key** — Only public anon key is safe
4. **Edit `main.dart` or `pubspec.yaml` without coordination** — Shared files

### ✅ Do This

1. **Work only in your module's folder** — `lib/modules/<your-module>/`
2. **Commit frequently** — Small, focused commits
3. **Sync `main` before starting new work** — Avoid painful merges
4. **Use branches** — Create feature branch like `yourname-module1`
5. **Create PRs** — Get reviewed before merging to `main`
6. **Reuse shared UI before writing new UI** — check `lib/theme/` (`filter_controls.dart`, `segmented_chips.dart`, `page_header.dart`, `tokens.dart`) and `lib/modules/leakage/screens/style.dart` for an existing widget before hand-rolling a new filter bar, card, or pill. Worker and Admin screens that show the same kind of thing (an alert, a report, a filter row) should render off the *same* widget, not two copies that can drift apart.

---

## Supabase Connection

### For Running the App
**Nothing to do.** The app auto-connects using the embedded public key. All team members share the same cloud database.

### For Direct Database Management (Claude Code / MCP)
1. Ask project owner to invite you: Supabase dashboard → Project Settings → Team → Invite member
2. Accept the invite
3. In terminal: `claude` → `/mcp` → select **supabase** → **Authenticate** → log in via browser
4. Restart Claude Code session

---

## Development Workflow (Git)

### Daily Loop

1. **Sync main**
   ```bash
   git checkout main
   git pull origin
   ```

2. **Create feature branch**
   ```bash
   git checkout -b yourname-module1
   ```

3. **Make changes** in your module folder only

4. **Commit frequently**
   ```bash
   git add .
   git commit -m "Add NRW detection engine"
   ```

5. **Push to GitHub**
   ```bash
   git push origin yourname-module1
   ```

6. **Create Pull Request** on GitHub

7. **Wait for review** → Merge to `main`

8. **Everyone syncs**
   ```bash
   git checkout main
   git pull origin
   ```

### Handling Conflicts

If GitHub reports conflicts:
1. Open conflicting file
2. Find `<<<<<<<` / `=======` / `>>>>>>>`
3. Edit to keep both/correct version
4. Delete conflict markers
5. Mark resolved in GitHub Desktop → commit merge

---

## Troubleshooting

### `flutter: command not found`
- Restart PowerShell/terminal completely
- Or use full path: `C:\flutter\bin\flutter.bat run`

### Emulator won't start
- Check Android Studio → Device Manager
- Delete outdated emulator, create new one with API 34+

### Gradle build fails
- Run `flutter pub get` again
- Delete `build/` folder and rebuild
- Check internet connection (large downloads)

### Supabase connection fails
- App requires internet connection
- Check Supabase status: https://supabase.com/status
- Verify public key in `lib/main.dart` is correct

### Hot reload not working
- Stop and restart `flutter run`
- Make sure you're in debug mode (default)

---

## Useful Commands

```bash
flutter --version              # Check Flutter version
flutter doctor                 # Diagnose environment issues
flutter devices                # List available emulators/devices
flutter pub get                # Download/update dependencies
flutter pub outdated           # See outdated packages
flutter run                    # Launch app in debug mode
flutter run --release          # Build optimized release APK
flutter clean                  # Delete build artifacts
flutter pub upgrade            # Upgrade all dependencies
```

---

## File Permissions & Access

| File/Folder | Access | Notes |
|---|---|---|
| `lib/modules/<your-name>/` | ✅ Full | Your module — edit freely |
| `lib/modules/<other>/` | 🚫 Read-only | Don't edit others' work |
| `lib/main.dart` | ⚠️ Coordinate | Shared entry point |
| `pubspec.yaml` | ⚠️ Coordinate | Shared dependencies |
| `assets/` | 🚫 Read-only | Government data reference |

---

## Supabase RLS & Security

- **Row Level Security (RLS)** is enabled on `alerts`, `readings`, `reports`
- **Policies are permissive** (no per-user auth yet—future enhancement)
- **Public anon key** is intentionally embedded in `lib/main.dart`
- **Never commit service_role key** to GitHub

Historically this was a deliberate simplification — all team members shared a single "Worker X" persona. That's no longer true: each worker account now has its own display name, and alerts carry per-worker ownership (`handled_by`/`handled_by_id` on `alerts`) — once a worker starts investigating an alert, only they can submit the report that resolves or closes it out. Not Fixed resets ownership, so any worker can pick a failed attempt back up.

---

## Questions & Support

- **Flutter docs:** https://flutter.dev/docs
- **Supabase docs:** https://supabase.com/docs
- **Dart docs:** https://dart.dev/guides
- **Team chat:** Coordinate on shared files in team messaging

---

## Checklist Before Final Submission

- [ ] All AI use disclosed (Appendix A)
- [ ] All comments removed from code
- [ ] All team members' work merged to `main`
- [ ] App runs without errors in emulator
- [ ] All modules launch and display data
- [ ] Supabase connection works (Module 3)
- [ ] No secrets in code (keys, passwords)
- [ ] .gitignore is up-to-date
- [ ] README still reflects current project state
