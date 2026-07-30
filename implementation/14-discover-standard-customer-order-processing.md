# Implementation 14 — Discover Standard Customer Order Processing

## Current Status

```text
Customer validation             : FULLY COMPLETED
Process/Reprocess design        : STARTED — DISCOVERY ONLY
Standard Customer Order IDO     : CONFIRMED — SL.SLCos
Standard line IDO/collection    : NOT YET CONFIRMED
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

Direct SQL insertion into those standard tables is prohibited.

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

One call will process one staged order group:

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

This belongs to the standard **Customers** form and is not the Customer Order header IDO.

```text
SL.SLCustomers = customer-master IDO only
```

No standard object was modified.

## Confirmed Customer Order Header IDO

A subsequent screenshot from the correct standard **Customer Orders** form displayed:

```text
Primary Collection : SL.SLCos
Collection          : SL.SLCos
Collection Name     : blank / not assigned
```

Decision:

```text
Standard Customer Order header IDO : SL.SLCos — CONFIRMED
```

The empty Collection Name is acceptable; the authoritative collection/IDO value shown by the tenant is `SL.SLCos`.

Evidence:

```text
tests/evidence/2026-07-30-standard-customer-order-header-ido.md
```

No standard form, collection, IDO, or method was modified during this discovery.

## Current Small Step — Identify the Customer Order Line Collection

Stay in the standard **Customer Orders** form Design Mode and perform only this discovery step:

1. inspect the secondary collections listed under Collections;
2. select collections one at a time without changing them;
3. find the collection whose property list contains line-level fields such as:

```text
CoNum
CoLine
Item
QtyOrdered
UM
Price
DueDate
Whse
```

4. capture a screenshot showing:

```text
Secondary Collection label
Collection / IDO name
Collection Name
several visible line-level properties
```

5. send the screenshot.

Do not assume the line IDO name from another tenant.

Do not modify or save the standard form or collection.

Do not create a custom stored procedure, IDO method, Process button, Customer Order, or API receive method during this step.

## Next Step After Line IDO Confirmation

After the exact Customer Order line collection is confirmed:

```text
- inspect available standard methods on SL.SLCos;
- inspect available methods on the confirmed line IDO;
- identify the supported header-number generation and save process;
- identify required header and line properties;
- design the custom Process/Reprocess wrapper without direct standard-table inserts.
```

These actions will be performed one small step at a time.