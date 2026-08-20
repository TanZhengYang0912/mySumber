-- Alerts now carry their own review state, replacing the anomaly_cases staging
-- tier. An alert is inserted as 'pending_review', the alerts_ai_analysis
-- trigger writes its AI columns, and the admin approves it into the worker
-- queue ('pending') or rejects it ('faults' — already in the constraint).
alter table public.alerts drop constraint alerts_status_check;
alter table public.alerts add constraint alerts_status_check
  check (status = any (array[
    'pending_review', 'pending', 'investigating',
    'resolved', 'not_fixed', 'dismissed', 'faults'
  ]));

-- Dedup key, mirroring the pattern already proven on anomaly_cases: re-running
-- the seed must never resurrect an alert the admin has rejected.
--
-- Deliberately NOT a partial index. Postgres cannot infer a partial index from
-- a plain `on conflict (source_key)` — every caller would have to repeat the
-- `where source_key is not null` predicate. A plain unique index already allows
-- any number of NULLs, so the pre-existing rows are unaffected.
alter table public.alerts add column if not exists source_key text;
create unique index if not exists alerts_source_key_key
  on public.alerts (source_key);
