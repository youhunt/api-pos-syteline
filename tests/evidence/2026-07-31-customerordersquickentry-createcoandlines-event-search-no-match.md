# Evidence — CustomerOrdersQuickEntry CreateCoAndLines Event Search No Match

Date: 31 July 2026

## Tenant Form

```text
CustomerOrdersQuickEntry
```

## Observation

In Design Mode, the form-level `Event Handlers` tab was filtered with:

```text
CreateCoAndLines
```

The result grid was empty. No matching handler row was displayed under the visible columns:

```text
Sequence
Response
Disabled
Response Parameters
```

## Confirmed Interpretation

The form-level Event Handlers search did not surface a direct handler entry matching `CreateCoAndLines`.

This does **not** prove that the method is absent from all form logic. A reference may still exist in:

```text
- a component-generated event;
- a form or global script;
- inherited/base-form logic;
- standard SLCos/SLCoitems parent-child persistence;
- an event whose name does not contain the method name.
```

The confirmed collection model remains:

```text
oSLCos / SLCos
└── oLines / SLCoitems
```

## Next Controlled Step

Select the visible `Quick Order Verification` button in Design Mode and capture its event-generation property, such as `Event To Generate`, `Event`, or the tenant-equivalent field.

Do not click the button at runtime and do not save or modify the form.

## Safety Result

```text
No form save
No form customization
No Customer Order creation
No CreateCoAndLines invocation
No direct SQL insert
```
