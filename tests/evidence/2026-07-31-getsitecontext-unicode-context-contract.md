# Evidence — GetSiteContext Unicode CONTEXT_INFO Contract

Date: 31 July 2026
Tenant database: `LENSA_SL_CSI_BAK`

## Tenant-confirmed function

The tenant returned this implementation:

```sql
CREATE FUNCTION dbo.GetSiteContext()
RETURNS NVARCHAR(8)
AS
BEGIN
    DECLARE @Site SiteType;

    SELECT @Site = RTRIM(CAST(CONTEXT_INFO() AS NVARCHAR(8)));

    RETURN @Site;
END;
```

## Confirmed consequence

`CONTEXT_INFO` must contain the UTF-16/Unicode byte representation of the site value. Populating it from `VARCHAR(8)` is incorrect because `dbo.GetSiteContext()` casts the binary value back to `NVARCHAR(8)`.

Incorrect:

```sql
CONVERT(VARBINARY(128), CONVERT(VARCHAR(8), @SiteRef))
```

Correct:

```sql
CONVERT(VARBINARY(128), CONVERT(NVARCHAR(8), @SiteRef))
```

For `DEFAULT`, the incorrect ANSI bytes are interpreted as Unicode character pairs, causing `dbo.GetSiteContext()` to differ from `inserted.orig_site`. That difference enters the `co_mstIup` remote-note branch and attempts `TransferNotesToSiteSp` to target `DEFAULT`.

## Required controlled verification

```sql
DECLARE
    @PreviousContextInfo VARBINARY(128) = CONTEXT_INFO(),
    @SiteContextInfo     VARBINARY(128),
    @EmptyContextInfo    VARBINARY(128) = 0x,
    @SiteRef             NVARCHAR(8) = N'DEFAULT';

SET @SiteContextInfo = CONVERT
(
    VARBINARY(128),
    CONVERT(NVARCHAR(8), LTRIM(RTRIM(@SiteRef)))
);

SET CONTEXT_INFO @SiteContextInfo;

SELECT
    dbo.GetSiteContext() AS GetSiteContext,
    CONTEXT_INFO() AS ContextInfoBinary,
    CONVERT(NVARCHAR(8), CONTEXT_INFO()) AS ContextInfoText;

IF @PreviousContextInfo IS NULL
    SET CONTEXT_INFO @EmptyContextInfo;
ELSE
    SET CONTEXT_INFO @PreviousContextInfo;
```

Expected result:

```text
GetSiteContext = DEFAULT
ContextInfoText = DEFAULT
```

The Customer Order procedure must use the same Unicode conversion, verify `dbo.GetSiteContext() = @SiteRef` before inserting `co_mst`, and restore the previous context after success or rollback.
