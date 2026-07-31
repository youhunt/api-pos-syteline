# Evidence — CustomerOrdersQuickEntry Standard Save Events Visible

Date: 31 July 2026

## Tenant Form

```text
CustomerOrdersQuickEntry
```

## Observation

In Design Mode, the Event Handlers list displayed the following standard events:

```text
StdFormSave
StdFormSaveCompleted
StdFormSaveCompletedLine
StdObjectNew
StdObjectSave
StdObjectSaveCompleted
StdObjectSaveCurrentCompleted
StdObjectSaveLine
```

No direct `CreateCoAndLines` handler was displayed in the earlier filtered search.

## Confirmed Interpretation

The form exposes the Mongoose standard save lifecycle for the form and bound objects. This supports the possibility that `CustomerOrdersQuickEntry` persists:

```text
oSLCos / SLCos
└── oLines / SLCoitems
```

through ordinary parent/child collection saving rather than through a form handler explicitly named `CreateCoAndLines`.

This observation does not yet establish the internal responses attached to these events and does not prove that `CreateCoAndLines` is unused elsewhere.

## Next Controlled Step

Expand only:

```text
StdFormSave
```

and capture every visible handler row, including:

```text
Sequence
Response
Disabled
Response Parameters
```

Do not execute Save at runtime and do not modify or save the form definition.

## Safety Result

```text
No Customer Order save
No CreateCoAndLines invocation
No form modification
No metadata save
No direct SQL insert
```
