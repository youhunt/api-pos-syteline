# Evidence — CustomerOrdersQuickEntry Selected as Standard CO Call-Site Candidate

Date: 31 July 2026

## Tenant Observation

The user identified the standard tenant form:

```text
CustomerOrdersQuickEntry
```

and confirmed that the visible form contains both:

```text
Customer Order header
Customer Order item/detail lines
```

This makes it a materially stronger discovery target than `Form Control`, whose visible Utilities tab was confirmed to contain only device-type synchronization actions.

## Current Interpretation

`CustomerOrdersQuickEntry` is now the primary candidate for discovering the standard header-plus-line creation flow that may:

```text
- bind to the standard Customer Order header and line IDOs;
- invoke SL.SLCos.CreateCoAndLines; or
- reveal an equivalent standard save/event sequence.
```

The exact collection bindings, event handlers, scripts, and method calls are not yet tenant-confirmed. No claim is made yet that this form invokes `CreateCoAndLines`.

## Next Controlled Step

Open `CustomerOrdersQuickEntry` in Design Mode and capture only the form collection definitions showing:

```text
- primary collection;
- secondary/subcollection names;
- collection aliases;
- parent-child relationship, when visible.
```

Do not save, check out, customize, or execute a Customer Order during this step.

## Safety Result

```text
No CreateCoAndLines invocation
No Customer Order creation
No form modification
No metadata save
No direct SQL insert
```
