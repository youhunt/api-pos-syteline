# Implementation 13 — SMK069 Customer Validation

## Current Status

```text
Base form and Preview : COMPLETED
process_status display: VERIFIED
process_status read-only: VERIFIED
Customer validation  : NOT STARTED
Process/Reprocess     : NOT STARTED
Customer Order creation: NOT STARTED
API ingestion         : NOT STARTED
```

## Validation Requirement

The first mandatory business validation is:

```text
cust_num from SMK069_temp_sales_mst must exist in customer_mst
```

## Validation Scope

Validation is performed for one staged Customer Order group:

```text
SiteRef + co_num
```

All lines belonging to the selected `SiteRef + co_num` must be evaluated together.

Expected outcomes:

### Customer exists

```text
process_status = V
validation_msg = NULL or empty
error_msg      = NULL or unchanged according to later processing rules
```

### Customer does not exist or is blank

```text
process_status = E
validation_msg = Customer <cust_num> tidak ditemukan di customer_mst.
```

No Customer Order is created during this validation step.

## Architecture Rule

Do not implement the customer lookup as UI-only logic. The validation must be reusable by:

```text
Error Processing form
CSV import
REST API ingestion
Process/Reprocess action
```

The target implementation is a controlled server-side IDO method or supported Mongoose server-side method. The form will call the reusable method; it must not contain duplicated customer-validation logic.

## Object Naming — Pending Tenant Confirmation

Before creating a method, verify the method configuration options available in the tenant for:

```text
IDO: ue_SMK069TempSales
```

Do not invent a stored procedure, extension class, or method type until the tenant screen confirms which method implementation types are available.

Proposed method responsibility:

```text
ValidateCustomer
```

Proposed inputs:

```text
SiteRef
co_num
```

Proposed outputs:

```text
ReturnCode
ReturnMessage
```

These names remain proposed until the tenant method screen is reviewed.

## Current Small Step

Open the tenant's IDO method maintenance screen and locate:

```text
ue_SMK069TempSales
```

Start a new method record only far enough to show the available method type/options. Do not save a method yet.

Capture or send a screenshot showing:

```text
IDO name
Method name field
Method type / implementation type options
Parameter area, if visible
```

After the tenant options are confirmed, the exact implementation instructions will be documented and performed one small step at a time.

## Stop Point

Do not create the Process button, Customer Order, CSV importer, or REST endpoint during this step.