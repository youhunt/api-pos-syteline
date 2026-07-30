# Implementation 14 — Discover Standard Customer Order Processing

## Current Status

```text
Customer validation             : FULLY COMPLETED
Process/Reprocess design        : STARTED — DISCOVERY ONLY
Standard Customer Order IDO     : CONFIRMED — SL.SLCos
Standard Customer Order line IDO: CONFIRMED — SL.SLCoitems
Standard header method/process  : NOT YET CONFIRMED
Standard line method/process    : NOT YET CONFIRMED
Customer Order creation         : NOT STARTED
Form Process button             : NOT STARTED
Controlled API receive method   : NOT STARTED
```

## Objective

Identify the exact standard Customer Order IDOs and supported business process available in the user's SyteLine tenant before creating the custom Process/Reprocess method.

The final custom processor must create:

```text
Customer Order Header
Customer Order Lines
```

with the intended result stored by standard SyteLine processing in:

```text
co_mst
coitem_mst
```

Direct SQL insertion into those tables is prohibited.

## Reusable Architecture

```text
Error Processing form Process action
or
controlled POS/API service
        ↓
custom reusable Process/Reprocess method
        ↓
customer validation
        ↓
standard SyteLine Customer Order IDO/business process
        ↓
co_mst + coitem_mst
```

The form and future API must call the same processing core.

## Processing Scope

One call processes one staged order group:

```text
SiteRef + co_num
```

All staging lines belonging to that group must be handled together.

## Discovery Attempt 1 — Customers Form

The first screenshot displayed:

```text
Primary Collection : SL.SLCustomers
Collection Name    : oCustomers
```

This belongs to the standard **Customers** form and is not a Customer Order IDO.

```text
SL.SLCustomers = customer-master IDO only
```

No standard object was modified.

## Confirmed Customer Order Header IDO

The correct standard **Customer Orders** form displayed:

```text
Primary Collection : SL.SLCos
Collection          : SL.SLCos
Collection Name     : blank / not assigned
```

Decision:

```text
Standard Customer Order header IDO : SL.SLCos
```

Evidence:

```text
tests/evidence/2026-07-30-standard-customer-order-header-ido.md
```

## Confirmed Customer Order Line IDO

The standard **Customer Order Lines** form displayed:

```text
Primary Collection : SL.SLCoitems
Collection          : SL.SLCoitems
Collection Name     : blank / not assigned
```

Decision:

```text
Standard Customer Order line IDO : SL.SLCoitems
```

The line form and its collection are separate from the header form, but together they confirm the tenant's standard header and line entity IDOs:

```text
Header : SL.SLCos
Lines  : SL.SLCoitems
```

Evidence:

```text
tests/evidence/2026-07-30-standard-customer-order-line-ido.md
```

No standard form, collection, IDO, property, or method was modified during discovery.

## Important Limitation

Confirming the entity IDOs does not yet prove the supported creation process.

Still unknown:

```text
- standard header methods available on SL.SLCos
- standard line methods available on SL.SLCoitems
- Customer Order number generation method
- minimum required properties for header insertion
- minimum required properties for line insertion
- whether the tenant expects UpdateCollection, a standard method, or another supported process
```

Do not implement the custom processor until these tenant-specific details are confirmed.

## Current Small Step — Inspect Header Methods

Perform only this discovery step:

1. exit Design Mode without saving changes to the standard forms;
2. open **IDO Methods**;
3. select IDO `SL.SLCos`;
4. do not create, edit, resync, or save any method;
5. capture a screenshot showing the method-name list available for `SL.SLCos`;
6. if one method must be selected to display the list, select it without changing any field;
7. send the screenshot.

Do not execute a method during this step.

Do not inspect `SL.SLCoitems` methods in the same step.

Do not create the custom Process method, Process button, Customer Order, CSV import, or API receive method yet.

## Next Step After Header Method List

After the tenant method list for `SL.SLCos` is visible:

```text
- identify methods related to order-number generation or initialization;
- inspect one relevant method's parameters;
- determine whether standard entity updates or a dedicated business method should create the header;
- then inspect SL.SLCoitems separately.
```

Each discovery action will be performed one small step at a time.