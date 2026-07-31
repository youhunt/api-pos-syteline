# Evidence — Tax Code View and Site Context Confirmed

Date: 31 July 2026
Tenant database: `LENSA_SL_CSI_BAK`

## Tenant diagnostic result

The controlled diagnostic returned:

```text
GetSiteContext  : DEFAULT
ContextInfoText : DEFAULT
DatabaseCollation: SQL_Latin1_General_CP1_CI_AS
```

The physical table lookup returned one matching row:

```text
Table          : dbo.taxcode_mst
site_ref       : Default
tax_system     : 1
tax_code_type  : R
tax_code       : PPN11%
description    : PPN 11%
tax_rate       : 11.00000
SiteMatchesContext : 1
```

The standard object was confirmed as:

```text
SchemaName            : dbo
ObjectName            : taxcode
ObjectType            : V
ObjectTypeDescription : VIEW
```

The view `dbo.taxcode` also returned `PPN11%` for tax system 1 and type `R`.

## Confirmed interpretation

```text
Unicode site context is correct       : YES
Database collation is case-insensitive: YES
PPN11% exists in taxcode_mst          : YES
PPN11% is visible through dbo.taxcode : YES
Simple missing tax-code diagnosis     : INVALIDATED
```

The remaining standard error cannot be explained by a missing row, site-case mismatch, or the `dbo.taxcode` view hiding the row.

The complete standard error text and the exact validator object are required before modifying tax data or trigger behavior.

## Next read-only step

Read the complete error stored by the custom procedure and identify standard modules that contain tax-code validation references:

```sql
SELECT
    LEN(error_msg) AS ErrorLength,
    error_msg,
    CONVERT(XML, N'<e>' +
        REPLACE(REPLACE(REPLACE(error_msg, N'&', N'&amp;'), N'<', N'&lt;'), N'>', N'&gt;')
        + N'</e>') AS ErrorAsXml
FROM dbo.ue_SMK069_temp_sales_mst
WHERE SiteRef = N'DEFAULT'
  AND LTRIM(RTRIM(co_num)) = N'TEST000001';
```

Do not change `taxcode_mst`, `dbo.taxcode`, standard triggers, or replication configuration until the full message and validator source are known.
