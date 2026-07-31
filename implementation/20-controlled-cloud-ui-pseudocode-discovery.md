# Implementation 20 — Controlled Cloud UI Pseudo-Code Discovery

## Status

```text
Environment                         : Infor Cloud tenant
Active direction                    : controlled Cloud UI execution
Passive metadata-only discovery     : paused
FormsAndObjects method metadata     : confirmed
Pseudo-code generator parameters    : confirmed
GetUtilitiesOutput parameters       : confirmed
Method invocation                   : not started
```

## Confirmed Method Flow Candidate

Tenant metadata supports this candidate flow:

```text
UtilitiesListNames
→ UtilitiesLoadObjects / UtilitiesLoadObjects2
→ UtilitiesGeneratePseudoCode / UtilitiesGeneratePseudoCode2
→ GetUtilitiesOutput(SessionID, SegmentNumber)
```

This sequence is still an inference. No method has been invoked.

## Why Start in Cloud UI

The pseudo-code generators require tenant-specific `VARIANT` values:

```text
SourceConfig
TargetConfig
Source
DatabaseName
Type
Scope
RelativePosition or Options
ObjectList
Version
CompareIncludeSettings
```

Their valid values and serialization formats are not published in the metadata contract. The Cloud `Form Control` UI is expected to populate these values safely and consistently with the tenant configuration.

## First Controlled Step

1. Open the Infor Cloud application.
2. Use global form search and open `Form Control`.
3. Open the `Utilities` tab/section.
4. Do not click Generate, Process, Import, Export, Update, or Delete.
5. Capture one screenshot showing all visible fields, dropdowns, defaults, and buttons in the Utilities section.

The screenshot will determine the next single action and the tenant-valid object type/scope/configuration values.

## Safety Boundary

```text
- No production order processing.
- No CreateCoAndLines call.
- No metadata modification.
- No form synchronization or upgrade action.
- No import/export action.
- No pseudo-code generation before the visible defaults are reviewed.
- No direct SQL execution.
```

## Evidence

```text
tests/evidence/2026-07-30-formsandobjects-idomethods-list.md
tests/evidence/2026-07-30-formsandobjects-pseudocode-method-parameters.md
tests/evidence/2026-07-31-formsandobjects-getutilitiesoutput-parameters.md
```
