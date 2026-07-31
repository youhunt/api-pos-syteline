# Evidence — SMK069 Tax Master Contract

Date: 31 July 2026
Tenant database: `LENSA_SL_CSI_BAK`

## Tenant-confirmed tables

```text
Tax code master      : dbo.taxcode_mst
Tax parameter master : dbo.taxparms_mst
```

## Tenant-confirmed tax parameter state

`dbo.taxparms_mst` for site `Default` confirms:

```text
nmbr_of_systems      : 1
prompt_for_system1   : 1
prompt_for_system2   : 0
```

## Tenant-confirmed valid tax codes

For site `Default`, tax system `1`, and tax code type `R` (Rate):

```text
NONPPN  — PPN 0   — 0.00000
NPPN    — Non PPN — 0.00000
PPN     — PPN 0   — 0.00000
PPN11%  — PPN 11% — 11.00000
```

The runtime value `TAX` does not exist in `dbo.taxcode_mst` for the active site/system/type combination.

## Runtime interpretation

The standard SyteLine tax validation error is expected when `co_mst.tax_code1 = 'TAX'`.

The current procedure derives the final value as:

```sql
SET @TaxCode = COALESCE(@StageTaxCode, @TaxCode);
```

Therefore `TAX` can come from either:

```text
staging tax_code1
customer_mst.tax_code1
```

For controlled testing, the staging order must use a tenant-valid code selected according to functional intent. Do not invent or insert a new tax code merely to bypass the validation.

## Next controlled step

Inspect both sources for the test order and update only staging when an explicit test code has been agreed:

```sql
SELECT DISTINCT
    s.tax_code1 AS StagingTaxCode,
    c.tax_code1 AS CustomerTaxCode,
    s.cust_num
FROM dbo.ue_SMK069_temp_sales_mst AS s
LEFT JOIN dbo.customer_mst AS c
  ON c.site_ref = s.SiteRef
 AND LTRIM(RTRIM(c.cust_num)) = LTRIM(RTRIM(s.cust_num))
 AND c.cust_seq = 0
WHERE s.SiteRef = N'DEFAULT'
  AND LTRIM(RTRIM(s.co_num)) = N'TEST000001';
```
