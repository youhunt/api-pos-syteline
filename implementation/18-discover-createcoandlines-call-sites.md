# Implementation 18 — Discover Standard CreateCoAndLines Call Sites

## Status

```text
Environment                                      : DEV / Infor Cloud tenant
Active Customer Order path                       : SL.SLCos.CreateCoAndLines
Direct-insert stored procedure                   : DEFERRED FALLBACK
Base64 input requirement                         : CONFIRMED
Decoded payload type                             : JSON object / JObject
Exact business JSON schema                       : NOT CONFIRMED
Controlled malformed probes                      : COMPLETED
All post-probe co_mst checks                     : ZERO ROWS
Direct event/action text searches                : EXHAUSTED / ZERO ROWS
Form Control Utilities tab                       : DEVICE SYNC ONLY
Current discovery target                         : tenant form list / standard CO form call site
```

## Confirmed Runtime Contract

```text
CoAndLineInfoJson
→ Base64 decode
→ JSON object / JObject parse
→ locate expected nonblank order structure
→ business validation
→ Customer Order and line processing
```

Business-result rules:

```text
- MessageCode = 0 is framework success only.
- CoResult is an input/output message parameter.
- CoResult is returned as a JSON-array string.
- Business Status must be evaluated independently.
- ErrrorMessage may be present with three r characters.
```

## Controlled Probe History

```text
Probe 1 : raw {                         → invalid Base64
Probe 2 : ew==                          → decoded { → JObject parser failure
Probe 3 : e30=                          → decoded {} → blank order input
Probe 4 : eyJwcm9iZSI6dHJ1ZX0=         → decoded {"probe":true} → blank order input
```

Four read-only `dbo.co_mst` checks after the probes returned zero rows and no SQL error.

## Completed Direct Metadata Searches

These read-only searches completed successfully and returned zero rows:

```text
EventHandlers.MethodToCall LIKE '%CreateCoAndLines%'
EventActions.Parameters LIKE '%CreateCoAndLines%'
EventActions.ExpandedParameters LIKE '%CreateCoAndLines%'
EventActions.SubstitutedParameters LIKE '%CreateCoAndLines%'
EventActionRevisions.Parameters LIKE '%CreateCoAndLines%'
```

`EventActionRevisions.ExpandedParameters` could not be filtered because the tenant returned `IllegalFilterException`, `MessageCode = 450`, and `Items = null`. This was a rejected filter, not a zero-row result.

`EventHandlerRevisions` exposes handler context and child action collections but no direct call-site text property.

## FormsAndObjects Findings

Tenant discovery selected `FormsAndObjects` because it is described as:

```text
Wrapper for FormControl and FormSync
```

Its property contract is utility-oriented and does not expose obvious persistent properties named `FormName`, `Script`, `EventName`, `MethodToCall`, or `Parameters`.

`IdoMethods` confirmed 37 methods. Relevant names included:

```text
UtilitiesListNames
UtilitiesLoadObjects / UtilitiesLoadObjects2
UtilitiesGeneratePseudoCode / UtilitiesGeneratePseudoCode2
GetUtilitiesOutput
```

Both pseudo-code generators have 12 `VARIANT` parameters. Their only parameter-name difference is sequence 7:

```text
UtilitiesGeneratePseudoCode  : RelativePosition
UtilitiesGeneratePseudoCode2 : Options
```

`SegmentCount` is input/output. `GetUtilitiesOutput` accepts only `SessionID` and `SegmentNumber`.

## Cloud UI Correction

The tenant `Form Control > Utilities` screenshot showed only device-type synchronization buttons:

```text
Sync Dev from Master
Sync Master from Dev
Sync Archive from Master
Sync Master from Archive
```

Therefore the visible Utilities tab is not the expected pseudo-code generation interface. No synchronization action was executed, and that UI path is stopped.

## User Decision

On 31 July 2026, the user explicitly reconfirmed:

```text
Continue with SL.SLCos.CreateCoAndLines.
```

The direct-insert stored-procedure path remains fallback only.

## Active Discovery Plan

```text
1. Enumerate tenant form names through Form Control > Forms.
2. Identify the standard Customer Order entry form or another confirmed form call site.
3. Retrieve/read the selected form definition without checking it out or modifying it.
4. Extract the exact JSON-building and Base64-encoding contract.
5. Build one minimal valid DEV payload.
6. Invoke CreateCoAndLines once under controlled conditions.
7. Verify both co_mst and coitem_mst.
8. Reuse the verified contract for SMK069 Process/Reprocess.
```

## Current Small Step

In the already open `Form Control` screen:

```text
1. Select the Forms tab.
2. Keep Scope = Site.
3. Click Refresh List.
4. Capture the resulting form list and visible search/filter controls.
```

Do not use `Check out`, `Check in`, `Get`, `Unlock`, `Archive`, `Restore`, `Delete`, or any Sync action in this step.

## Evidence

```text
tests/evidence/2026-07-30-eventactionrevisions-idoinfo-properties.md
tests/evidence/2026-07-30-eventactionrevisions-parameters-createcoandlines-no-match.md
tests/evidence/2026-07-30-eventactionrevisions-expandedparameters-illegal-filter.md
tests/evidence/2026-07-30-eventhandlerrevisions-idoinfo-properties.md
tests/evidence/2026-07-30-formsandobjects-idomethods-list.md
tests/evidence/2026-07-30-formsandobjects-pseudocode-method-parameters.md
tests/evidence/2026-07-31-formsandobjects-getutilitiesoutput-parameters.md
tests/evidence/2026-07-31-user-reconfirms-createcoandlines-path.md
```

## Safety Boundary

```text
- No CreateCoAndLines invocation yet.
- No form checkout or metadata modification.
- No FormSync/device synchronization.
- No direct insert into co_mst or coitem_mst.
- No production Customer Order creation.
```
