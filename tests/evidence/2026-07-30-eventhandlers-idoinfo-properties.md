# Evidence — EventHandlers IDOInfo Properties

Date: 30 July 2026

## Purpose

Identify the tenant-published properties that can be used to locate a standard metadata call site for:

```text
SLCos.CreateCoAndLines
```

This was performed read-only through REST v1 IDOInfo for `EventHandlers`.

## Relevant Published Properties

The tenant response includes the following properties relevant to call-site discovery:

```text
EventName                  : String(50), required
Sequence                   : Short Integer, required
MethodToCall               : String(80)
IDOCollections             : String(255)
AppliesToObjects           : String(255), read-only
EventActions               : CONTAINS
InitialAction              : GUID
InitialActionSequence      : Short Integer
Description                : String(40)
Purpose                    : String(40)
AccessAs                   : String(50)
Active                     : Byte
Synchronous                : Byte
Transactional              : Byte
TriggeringProperty         : String(80)
EditableByWizard           : Byte
Obsolete                   : Byte
Suspend                    : Byte
```

Additional metadata, audit, workflow, override, applicability, and UDF properties are also published.

## Technical Interpretation

The strongest parent-handler property for the first filtered search is:

```text
MethodToCall
```

Supporting context properties are:

```text
EventName
Sequence
Description
Purpose
IDOCollections
AppliesToObjects
AccessAs
Active
InitialAction
InitialActionSequence
```

`EventActions` is a `CONTAINS` property and may hold child action records. Its child-property contract has not yet been inspected and must not be guessed.

## Next Read-Only Step

Load `EventHandlers` rows whose `MethodToCall` contains `CreateCoAndLines`. Do not inspect `EventHandlerRevisions` or edit metadata in the same step.

## Safety Result

```text
No CreateCoAndLines invocation
No Customer Order payload
No event-handler edit
No event-action edit
No Process/Reprocess implementation
```
