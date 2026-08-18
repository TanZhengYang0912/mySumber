# Offline Session Profile Cache Design

## Goal

Allow a previously authenticated user to cold-start MySumber without a network connection and open the existing read-only operational cache. The fix closes the current gap where Supabase restores a local auth session, but the mandatory online `profiles` query fails and `RoleState` routes the user back to Login.

## Scope

This change caches only the last account profile that Supabase successfully returned:

- user ID
- full name
- email
- role
- active/inactive status
- verification timestamp

Passwords, access tokens, refresh tokens, JWTs, OAuth credentials, API keys, and service-role keys remain outside the Drift business-data database. Supabase continues to own session persistence.

## Selected Architecture

### Local schema

Add a `local_account_profiles` Drift table keyed by Supabase user ID. Increase `LocalDatabase.schemaVersion` from 1 to 2 and create this table in the version-2 migration without deleting or replacing any existing cached operational tables.

Profiles are isolated by user ID. A cached profile can only be requested using the user ID from the currently restored Supabase session.

### Repository boundary

`AccountRepository` remains the account-profile access boundary. It receives:

- a Supabase-backed remote profile store;
- `LocalDatabase`;
- the shared `CacheStatus` notifier.

Its `currentProfile(userId)` flow is remote-first:

1. Query Supabase `profiles` using the session user ID.
2. If Supabase returns a profile, store it locally with a fresh verification timestamp and return it.
3. If Supabase successfully returns no profile, delete any cached profile for that user and return no profile.
4. If the request fails because of network connectivity, timeout, PostgREST connection failure, or Supabase 5xx, return only that same user's cached profile.
5. If the request fails because of authentication, RLS, permission, parsing, or programming errors, propagate the failure and do not read the local profile.

Successful Supabase results remain authoritative. Local database write failures are best-effort and do not hide a successful remote profile result.

### Authentication gate

`RoleState.checkExistingSession()` still requires `Supabase.auth.currentSession`. The local profile cache never creates a session and cannot make a logged-out user appear logged in.

When a session exists, `_applyProfile(session.user)` uses the cached repository flow. A successful offline fallback restores the same role mapping used online (`customer` becomes the app's `user` role). Explicit logout clears the in-memory role and Supabase session; cached rows may remain keyed by user ID but are inaccessible without a matching restored session.

## Security Behaviour

- Cached authorization is last-known authorization and can be stale while the device is offline. The app already prohibits offline writes, limiting offline access to previously synchronized read data.
- As soon as connectivity returns, the next profile load must revalidate against Supabase. An inactive worker or missing profile is denied according to the online result.
- A cached profile for user A is never considered for user B.
- User-editable Supabase `user_metadata` is not used to authorize roles.
- Permission and RLS errors never trigger offline fallback.
- Sensitive values are not included in local payloads or debug output.

## User Experience

After one successful online login and synchronization:

1. The user force-stops the app.
2. The device goes offline.
3. Supabase restores its persisted local session.
4. MySumber restores the matching cached account profile.
5. The user enters the appropriate role shell and sees the existing `Offline data` banner.
6. Pages display whatever operational data was previously cached; uncached scopes retain their existing unavailable/error state.

If there is no Supabase session or no matching cached profile, the user remains on Login with the existing profile/network error. The app does not invent an account or role.

## Testing

- Drift tests verify account profile insert, lookup, replacement, deletion, and user-ID isolation.
- Migration tests verify upgrading schema v1 to v2 preserves existing operational cache rows and creates `local_account_profiles`.
- Repository tests verify an online profile is cached and returned during a later connectivity failure.
- Repository tests verify empty cache plus connectivity failure preserves the original failure.
- Repository tests verify Auth, RLS/permission, mapping, and programming failures never use the cache.
- Repository tests verify a successful online missing-profile result removes stale local authorization.
- Role-state or widget coverage verifies a restored session plus offline cached profile produces a logged-in role instead of the Login screen at the available test seam.
- Existing `flutter analyze` and the full Flutter test suite must pass.

## Out of Scope

- Offline sign-in with email/password
- Storing or managing Supabase auth tokens in Drift
- Offline profile edits
- Offline write queues
- Replacing Supabase RLS or online role validation
- Background revalidation while the app is closed

## Success Criteria

- A user who previously logged in online can force-stop and cold-start the app offline without being incorrectly returned to Login.
- Cold-start access requires an existing Supabase session and a matching locally cached profile.
- Existing equipment, readings, alerts, reports, and usage caches survive the database migration.
- Permission failures cannot be bypassed with cached role data.
- No authentication secret is added to the local business database.
