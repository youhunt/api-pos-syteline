# Evidence — CustomerOrdersQuickEntry Collection Bindings

Date: 31 July 2026

## Tenant Form

```text
CustomerOrdersQuickEntry
```

The collection definitions were inspected in Design Mode without saving or modifying the form.

## Confirmed Header Binding

```text
Primary Collection : SLCos
Collection Name    : oSLCos
Custom Load Method : blank
```

A second top-level collection was also visible:

```text
Secondary Collection 2 : SLAppsParms
```

Its alias and role were not captured in this step.

## Confirmed Line Binding

The detail grid is configured as a `SubCollection Grid`.

Its subcollection specification confirms:

```text
Parent Collection      : primary collection
Subcollection Property : SLCoitems
Collection Name        : oLines
Custom Load Method     : blank
Update Locking         : Row
Record Cap Override    : -1
Reload After Child Save: enabled
```

Enabled standard operations include Navigate, Filter, Save, Note, Graph, Refresh, New/Copy, and Delete.

## Confirmed Interpretation

The form uses the standard Customer Order relationship:

```text
oSLCos / SLCos
└── oLines / SLCoitems
```

The line collection is not represented as an independent top-level Secondary Collection. It is exposed through the `SLCoitems` subcollection property of the primary `SLCos` collection.

This confirms the header-plus-line data model required by SMK069. It does **not** yet prove that the form invokes `SL.SLCos.CreateCoAndLines`. Because Save is enabled on the bound subcollection and no custom load method is shown, the form may use ordinary parent/child collection persistence or additional form events/scripts.

## Next Controlled Step

Inspect the form's event handlers/scripts and search specifically for:

```text
CreateCoAndLines
```

If no direct reference is present, inspect the Save/New/Quick Order Verification event sequence separately.

## Safety Result

```text
No form save
No form customization
No Customer Order creation
No CreateCoAndLines invocation
No direct SQL insert
```