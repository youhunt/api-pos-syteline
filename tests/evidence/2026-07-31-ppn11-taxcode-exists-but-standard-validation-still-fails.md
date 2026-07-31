# Evidence — PPN11% Exists but Standard Tax Validation Still Fails

Date: 31 July 2026
Tenant database: `LENSA_SL_CSI_BAK`

## Tenant-confirmed master data

Tax code table:

```text
dbo.taxcode_mst
```

Rows for site `Default`, tax system `1`, type `R`:

```text
NONPPN  — 0%
NPPN    — 0%
PPN     — 0%
PPN11%  — 11%
```

Tax parameters table:

```text
dbo.taxparms_mst
```

Tenant row confirms one tax system for site `Default`.

## Runtime result

After replacing staging tax code `TAX` with `PPN11%`, the standard trigger still returned:

```text
Error 50000 pada dbo.RaiseErrorSp line 121:
Tax Code that has [Tax System: 1] and [Tax Code Type: Rate]
and [Tax Code: PPN11%] and [Site: DEFAULT] ...
```

## Interpretation

`PPN11%` exists in `dbo.taxcode_mst`, so the blocker is no longer simple code absence. The standard lookup may be using a view, site-context value, collation-sensitive comparison, or another filter not yet identified.

## Next diagnostic

Run a lookup while the Unicode site context is active and compare direct-table and view behavior:

```sql
DECLARE
    @PreviousContextInfo VARBINARY(128) = CONTEXT_INFO(),
    @SiteContextInfo     VARBINARY(128),
    @EmptyContextInfo    VARBINARY(128) = 0x,
    @SiteRef             NVARCHAR(8) = N'DEFAULT';

SET @SiteContextInfo = CONVERT
(
    VARBINARY(128),
    CONVERT(NVARCHAR(8), @SiteRef)
);

SET CONTEXT_INFO @SiteContextInfo;

SELECT
    dbo.GetSiteContext() AS GetSiteContext,
    DATABASEPROPERTYEX(DB_NAME(), 'Collation') AS DatabaseCollation;

SELECT *
FROM dbo.taxcode_mst
WHERE LTRIM(RTRIM(site_ref)) = LTRIM(RTRIM(dbo.GetSiteContext()))
  AND tax_system = 1
  AND tax_code_type = N'R'
  AND LTRIM(RTRIM(tax_code)) = N'PPN11%';

SELECT OBJECT_ID(N'dbo.taxcode') AS TaxcodeViewObjectId;

IF OBJECT_ID(N'dbo.taxcode') IS NOT NULL
BEGIN
    SELECT *
    FROM dbo.taxcode
    WHERE tax_system = 1
      AND tax_code_type = N'R'
      AND LTRIM(RTRIM(tax_code)) = N'PPN11%';
END;

IF @PreviousContextInfo IS NULL
    SET CONTEXT_INFO @EmptyContextInfo;
ELSE
    SET CONTEXT_INFO @PreviousContextInfo;
```

Do not disable tax validation or triggers. The exact standard lookup path should be identified before changing master data or procedure mapping.
