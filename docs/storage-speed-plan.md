# Storage Page Speed Plan

Chosen direction: `Cached + Async`.

## Goal

Make the Storage tab open immediately from a persisted snapshot, then move expensive exact work into background summary refreshes or an explicit deep scan.

## Runtime Cache

- Persist a storage-only JSON cache under `~/Library/Application Support/Buoy/storage-scan-cache.json`.
- Keep the cache local to the storage feature with DTOs instead of making the broader dashboard models `Codable`.
- Cache payload includes:
  - schema version
  - captured timestamp
  - storage snapshot data required to render the page
  - scan completeness: `summaryOnly` or `deep`
  - last deep-scan timestamp
  - access fingerprint based on enabled protected scopes and enabled custom bookmarked paths
- Invalidate cached data when the schema changes or the access fingerprint changes.

## Scan Policy

- Split scanning into:
  - `summaryOnly`: cards, chart, cleanup targets, heavy folder summaries
  - `deep`: everything in `summaryOnly` plus the full largest-files enumeration
- Keep the existing supersession behavior so a newer scan cancels/supersedes older work.
- On Storage tab open:
  - render cached content immediately when a valid cache exists
  - otherwise render a seed state immediately using live `statfs` disk totals
  - if cached data is fresh (`<= 30 minutes`), do not auto-run a deep scan
  - if cached data is stale (`> 30 minutes`) or missing, start a background `summaryOnly` refresh
- Manual refresh becomes `Deep Scan` and always runs `deep`.

## UI Behavior

- Prefer cached content over a blocking spinner.
- Keep the current cards, chart, and table visible while a summary refresh or deep scan runs.
- Surface source/state labels for:
  - `Cached`
  - `Refreshing Summary`
  - `Deep Scan Running`
  - `Partial Scan`
- When the current snapshot is `summaryOnly`, explain that largest files are from the last deep scan or unavailable until a deep scan completes.
- Access toggles stay as-is; changing them invalidates the cache and triggers at most a `summaryOnly` refresh unless the user explicitly starts a deep scan.

## Data Changes

- Add internal storage-only types:
  - `StorageScanMode`
  - `StorageCacheRecord`
  - `StorageCacheSnapshotDTO`
  - `StorageCacheStore`
  - `StorageCacheStatus`
- Extend storage UI state to track:
  - cached vs live source
  - last deep-scan timestamp
  - scan completeness

## Verification Targets

- Warm-cache tab open shows meaningful content in `<= 250 ms`.
- No-cache tab open shows seed UI in `<= 500 ms`.
- Deep scan never blocks the main thread.
- The page stays interactive while summary or deep scans run.
- Cache persistence rejects stale schemas and mismatched access fingerprints.
