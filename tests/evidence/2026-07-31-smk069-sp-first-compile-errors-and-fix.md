# Evidence — SMK069ProcessCustomerOrderSp First Compile Errors and Fix

Date: 31 July 2026

## Tenant Compile Result

The first DEV compile attempt returned:

```text
Msg 243: Type CoNumType is not a defined system type
Msg 243: Type InfobarType is not a defined system type

Invalid column name 'Uf_date_pengambilan'
Invalid column name 'Uf_StartTime'
Invalid column name 'Uf_EndTime'
Invalid column name 'Uf_Item_price'
Invalid column name 'Uf_net_price'
Invalid column name 'Uf_price_aft_disc1'
Invalid column name 'Uf_price_aft_disc2'
Invalid column name 'Uf_price_aft_disc3'
```

## Confirmed Interpretation

The alias types are valid for procedure parameters and variables in this tenant, but they must not be used as target types in `CAST`/`CONVERT` expressions. The failing expressions were therefore changed from patterns such as:

```sql
CONVERT(CoNumType, ...)
CONVERT(InfobarType, ...)
CONVERT(UsernameType, ...)
```

to ordinary assignment or conversion to a system type such as `NVARCHAR`.

The listed `Uf_*` columns came from the separate legacy portal implementation and do not exist in the current SMK069 tenant objects. They were removed from the `co_mst` and `coitem_mst` insert lists.

## Corrective Revision

The revised procedure now:

```text
- assigns the generated string directly to @CreatedCoNum;
- assigns error text directly to @Infobar;
- uses SUSER_SNAME() through implicit assignment to @ProcessedBy;
- removes all unavailable header Uf_* columns;
- removes all unavailable line Uf_* columns;
- removes pickup-date/start-time/end-time parameters because no target columns exist;
- uses system types in the example execution block.
```

## Runtime Status

```text
First compile attempt : FAILED
Corrective SQL        : COMMITTED
Corrected compile     : NOT YET TENANT-VERIFIED
Procedure execution   : NOT STARTED
Customer Order rows   : NOT CREATED BY THIS ATTEMPT
```

## Safety Result

The failure occurred during procedure compilation, before any procedure execution. No header, line, staging-status, trigger, or constraint change was executed by the failed attempt.
