# SMK069 Shipment Scheduler Dashboard Rev.6 — Run Once async UX

Date: 2026-09-09

## Evidence from tenant

Background Task `SMK069ShipmentScheduler` was successfully submitted from the dashboard, but task 4608 returned `Task Failed - Error -1` while the dashboard still showed:

- API Active = 1
- Master Engine = 1
- Schedule Enabled = 1
- Run State = I
- Last Status = N
- Candidates = 0
- Queue contains `P96329` as READY, Attempt 0/5

The Rev.5 dashboard also showed POS User / POS Password blank.

## Root cause

`SMK069RunDueShipmentSchedule` validates POS Username and Password before claiming any due schedule. When either is blank, the extension method returns an error immediately. Because the schedule was never claimed or completed, LastRunDate / LastRunStatus / LastCandidates do not change and the queue remains READY.

Rev.5 also refreshed the form collections immediately after submitting the background task. This was misleading because TaskMan executes asynchronously: the refresh can finish before the background task has completed.

## Rev.6 UI changes

Generated file:

`FS_20260909_014506_dashboard_rev6_clear_run_once.XML`

Changes:

1. Added a dedicated `TASK CREDENTIALS (REQUIRED)` section.
2. Added a clear instruction that POS User / Password must be filled before Activate or Run Once Now.
3. Renamed `Run Now` to `Run Once Now`.
4. Renamed `Activate / Schedule` to `Activate Scheduler`.
5. Removed immediate Schedule/Dashboard/Queue refresh after submitting the one-time TaskMan job.
6. Added operator instruction: after the background task finishes, click `Refresh` to see Last Run and Queue changes.
7. No Form Script added; implementation remains native Mongoose event handlers.

## Expected test flow

1. Enter UAT POS User / Password.
2. Set Max / Run = 1.
3. Ensure API Active = 1, Master Engine = 1, Schedule Enabled = 1.
4. Click `Run Once Now`.
5. Confirm a new `SMK069ShipmentScheduler` task appears in Background Task History.
6. Open `Task Messages` if it fails.
7. After task completes, return to the dashboard and click `Refresh`.
8. Expected Last Run values:
   - Candidates = 1
   - Succeeded = 1, Failed = 0; or
   - Succeeded = 0, Failed = 1 with retry state updated.

## Security note

The current scheduler method still accepts POS credentials as TaskMan parameters. Use UAT credentials while validating behavior. Production hardening should move credentials to a server-side secret/configuration mechanism so they are not visible in task parameters/history.
