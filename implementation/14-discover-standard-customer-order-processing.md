# Implementation 14 — Discover Standard Customer Order Processing

## Current Status

```text
Customer validation             : FULLY COMPLETED
Process/Reprocess design        : STARTED — DISCOVERY ONLY
Standard Customer Order IDO     : NOT YET CONFIRMED
Standard header method/process  : NOT YET CONFIRMED
Standard line method/process    : NOT YET CONFIRMED
Customer Order creation         : NOT STARTED
Form Process button             : NOT STARTED
Controlled API receive method   : NOT STARTED
```

## Objective

Identify the exact standard Customer Order IDO and supported business process available in the user's SyteLine tenant before creating the custom Process/Reprocess method.

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

## Current Small Step — Identify the Standard Header IDO

Do only this tenant discovery step:

1. open the standard **Customer Orders** form;
2. enter Design Mode;
3. open the form's Collections configuration;
4. select the primary collection used by the form;
5. capture the exact standard IDO name and collection name shown by the tenant;
6. send a screenshot.

Do not modify the standard form or collection.

Do not create a custom stored procedure, IDO method, Process button, Customer Order, or API method during this step.

## Why Discovery Is Required

Standard IDO names and available methods can differ by SyteLine version, tenant configuration, installed industry solution, and extension metadata.

The tenant screen is therefore the source of truth. Do not assume object names from another environment.

## Next Step After Header IDO Confirmation

After the exact primary Customer Order IDO is confirmed:

```text
- inspect its available standard methods;
- identify the supported header-number generation and save process;
- identify the standard line collection/IDO;
- document required properties and method parameters;
- design the custom Process/Reprocess wrapper without direct standard-table inserts.
```

These actions will be performed one small step at a time.