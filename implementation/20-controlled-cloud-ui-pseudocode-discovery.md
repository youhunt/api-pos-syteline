# Implementation 20 — Controlled Cloud UI CreateCoAndLines Discovery

## Status

```text
Environment                         : Infor Cloud tenant
Active Customer Order path          : SL.SLCos.CreateCoAndLines
Direct-insert stored procedure      : fallback only
Form Control Utilities tab          : inspected — device sync only
Device/form synchronization         : not executed
CreateCoAndLines invocation          : not started
Exact business JSON schema          : not confirmed
```

## Confirmed Runtime Contract

```text
CoAndLineInfoJson
→ Base64 decode
→ JSON object / JObject parse
→ expected nonblank order structure
→ business validation
→ Customer Order processing
```

`CoResult` is an input/output message parameter returned as a JSON-array string. Framework `MessageCode = 0` does not by itself establish business success.

## Cloud UI Observation

The tenant `Form Control` screenshot showed that its visible `Utilities` tab contains only device-type synchronization actions:

```text
Sync Dev from Master
Sync Master from Dev
Sync Archive from Master
Sync Master from Archive
```

This is not the object pseudo-code surface inferred from `FormsAndObjects.UtilitiesGeneratePseudoCode%`. The Utilities-tab path is therefore stopped. No Sync action was executed.

## Active Discovery Plan

```text
1. Enumerate tenant form names from Form Control > Forms.
2. Identify the standard Customer Order entry form or another tenant-confirmed form that calls SL.SLCos.CreateCoAndLines.
3. Retrieve/read the selected form definition without modifying or checking it out.
4. Extract the exact JSON construction and Base64-encoding behavior.
5. Build one minimal valid DEV payload.
6. Invoke CreateCoAndLines once under controlled conditions.
7. Verify both co_mst and coitem_mst.
8. Reuse the confirmed contract for SMK069 Process/Reprocess.
```

## Immediate Next Step

In the currently open `Form Control` form:

1. Select the `Forms` tab.
2. Keep `Scope = Site`.
3. Click `Refresh List`.
4. Capture a screenshot showing the resulting list and available search/filter fields.
5. Do not select `Check out`, `Check in`, `Get`, `Unlock`, `Archive`, `Restore`, or `Delete`.

## Safety Boundary

```text
- No production order processing.
- No CreateCoAndLines call yet.
- No form checkout or modification.
- No device synchronization.
- No archive/restore/delete action.
- No direct SQL insert.
```

## Evidence

```text
tests/evidence/2026-07-30-formsandobjects-idomethods-list.md
tests/evidence/2026-07-30-formsandobjects-pseudocode-method-parameters.md
tests/evidence/2026-07-31-formsandobjects-getutilitiesoutput-parameters.md
tests/evidence/2026-07-31-user-reconfirms-createcoandlines-path.md
```
