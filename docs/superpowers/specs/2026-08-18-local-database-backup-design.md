# Local Database Backup Design

## Goal

Add a persistent local SQLite database that mirrors MySumber's operational Supabase data so the app can continue displaying the last successfully synchronized data when the network or Supabase is unavailable.

## Scope

The local database stores:

- Equipment nodes
- Equipment usage logs and anomaly flags
- Leakage readings
- Alerts
- Reports
- Customer utility entries

Supabase Auth credentials, passwords, access tokens, worker-management secrets, and service-role keys are outside the local business-data database. Authentication remains owned by `supabase_flutter`.

## Selected Approach

Use Drift on SQLite through `drift_flutter`. Drift provides typed table definitions, generated mapping code, transactions, batch operations, and explicit schema migrations on Android and iOS.

This phase implements a read-through local mirror, not full offline editing:

1. A repository requests data from Supabase.
2. On success, the repository replaces or upserts the corresponding local snapshot in a transaction.
3. The repository returns the fresh Supabase result.
4. If the request fails because the network or Supabase is unavailable, the repository returns the most recent local snapshot.
5. Successful online writes update the local database immediately after Supabase confirms the write.
6. Failed writes surface the existing error and are not queued for later upload in this phase.

This avoids conflict-resolution and duplicate-write problems while still providing persistent offline reads.

## Architecture

### Local database

Create a shared `LocalDatabase` under `lib/core/local_database/`. It owns Drift table definitions and local snapshot operations. The schema version starts at 1.

Local table names are prefixed or clearly named to avoid confusion with generated Drift classes:

- `local_equipment_nodes`
- `local_equipment_usage_logs`
- `local_readings`
- `local_alerts`
- `local_reports`
- `local_customer_utility_entries`
- `local_sync_metadata`

The local schema preserves Supabase primary keys. JSON-compatible payload columns may be used for fields that change frequently, but relational keys, timestamps, user ownership, deletion flags, statuses, and ordering fields remain typed columns so fallback queries are deterministic.

### Cache boundary

Repositories remain the only data-access boundary used by application state and screens. Screens do not call Drift directly.

Each affected repository receives both a Supabase client and `LocalDatabase`:

- `DatasetRepository`
- `LeakageRepository`
- `UsageRepository`

The repositories map existing domain models to Supabase maps and local rows. Existing model interfaces remain unchanged unless a missing identifier prevents safe caching.

### Dependency wiring

`main.dart` creates one `LocalDatabase` instance and injects it into repositories. The database is closed when the application container is disposed where practical. Tests use an in-memory Drift database.

## Data Flow

### Online read

Supabase is the source of truth. A successful response is mapped to domain models, written to SQLite in a transaction, and returned to the caller.

Snapshot-style lists use scope-aware replacement:

- Equipment list replaces the complete equipment snapshot.
- Logs replace only the selected equipment node's log scope.
- Alerts replace the requested alert scope without deleting unrelated cached scopes.
- Reports replace the requested report scope.
- Customer utility entries replace only the authenticated user's utility scope.

### Offline read

When the Supabase request throws a connectivity or service exception, the repository reads the matching SQLite scope. If cached rows exist, they are returned normally and the repository exposes that the result came from cache through a lightweight cache-status notifier or result metadata.

If neither Supabase nor SQLite has data, the current empty/error behavior remains; the app must not silently invent records.

### Online write

Create, update, and delete operations are sent to Supabase first. After confirmation, the matching local row is inserted, updated, or deleted. This ensures local storage never claims an unconfirmed change is synchronized.

### Logout and user separation

Shared operational data such as equipment and public worker queues can remain cached across sessions. User-owned customer utility entries include `user_id`, and local queries must filter by the currently authenticated user. Logging out does not expose one customer's cached entries to another customer.

## Error Handling

- Fallback occurs only for Supabase/network failures, not for model parsing or programming errors.
- Local database write failures do not hide a successful Supabase response; they are logged and the online result is still returned.
- Corrupt or incompatible local schemas are handled through Drift migrations. The app does not delete the database automatically.
- An offline/cache indicator is shown when a screen is displaying cached data, with the last successful sync time when available.
- Sensitive values are not written to debug logs.

## Security and Privacy

- Do not store Supabase passwords, JWTs, refresh tokens, service-role keys, or Groq API keys in the local business database.
- Customer utility entries are always queried by `user_id`.
- Local data is app-private SQLite storage. Device-level encryption is provided by the operating system; database-level encryption is outside this assignment phase.
- Existing Supabase RLS remains authoritative for online access. Local caching must never be used to bypass an online authorization failure.

## Testing

- Drift schema and mapping tests run against an in-memory database.
- Repository tests verify successful Supabase reads populate SQLite.
- Repository tests verify network failures return cached records.
- Repository tests verify empty cache plus network failure preserves the current error/empty behavior.
- User isolation tests verify customer A cannot read customer B's cached utility entries.
- Write-through tests verify local rows change only after the Supabase operation succeeds.
- Existing Flutter tests and `flutter analyze` must pass.

## Out of Scope

- Offline create, update, or delete queues
- Automatic background synchronization while the app is closed
- Conflict resolution between offline and online edits
- Local copies of authentication secrets
- Database-level encryption or biometric unlock
- Realtime Supabase subscriptions mirrored continuously in the background

These can be added in a later offline-first phase after the read-through backup is stable.

## Success Criteria

- After one successful online load, restarting the app without network still displays the cached equipment, logs, alerts, readings, reports, and customer utility entries.
- Data remains persisted across app restarts.
- Returning online refreshes the local snapshots from Supabase.
- Customer-owned cache data is isolated by authenticated user ID.
- No authentication secret is added to the local business database.
- All existing tests plus new local-database and fallback tests pass.
