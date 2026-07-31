# Evidence — NextKeys_mst SiteRef NULL during Customer Order insert

Date: 31 July 2026
Database: `LENSA_SL_CSI_BAK`

## Runtime result

After staging, customer, warehouse, currency, and item validation passed, the procedure reached Customer Order creation and returned:

```text
Error 515: Cannot insert the value NULL into column 'SiteRef',
table 'LENSA_SL_CSI_BAK.dbo.NextKeys_mst'; column does not allow nulls.
```

## Interpretation

The Customer Order insert is now reaching active SyteLine trigger/default logic. A trigger or called key-generation routine writes to `dbo.NextKeys_mst` and expects the current site to be available from the SQL connection context.

The procedure was executed directly from SSMS, so the Mongoose/CSI site context normally carried by the application connection was not present. The resulting `NextKeys_mst.SiteRef` was NULL.

No trigger or constraint should be disabled to solve this.

## Controlled correction

Before the `co_mst` insert, temporarily set SQL Server `CONTEXT_INFO` from `@SiteRef`:

```sql
DECLARE
    @PreviousContextInfo VARBINARY(128),
    @SiteContextInfo VARBINARY(128);

SET @PreviousContextInfo = CONTEXT_INFO();
SET @SiteContextInfo = CONVERT
(
    VARBINARY(128),
    CONVERT(VARCHAR(8), @SiteRef)
);

SET CONTEXT_INFO @SiteContextInfo;
```

Restore the previous context after success and in the outer CATCH because the connection can be pooled/reused:

```sql
IF @PreviousContextInfo IS NULL
BEGIN
    DECLARE @EmptyContextInfo VARBINARY(128) = 0x;
    SET CONTEXT_INFO @EmptyContextInfo;
END
ELSE
BEGIN
    SET CONTEXT_INFO @PreviousContextInfo;
END;
```

The procedure error text should also include `ERROR_PROCEDURE()` so the exact trigger/routine is visible on the next failure.

## Status

```text
Procedure compile                  : SUCCESS
Staging lookup                     : SUCCESS
Customer/warehouse/currency checks : SUCCESS
Item validation                    : SUCCESS after real item replacement
Customer Order insert reached      : YES
Current blocker                    : missing SQL connection site context
Customer Order committed           : NO
```
