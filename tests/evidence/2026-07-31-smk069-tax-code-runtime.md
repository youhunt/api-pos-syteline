# Evidence — SMK069 Tax Code Runtime

Date: 31 July 2026
Tenant database: `LENSA_SL_CSI_BAK`

## Runtime result

After correcting the site context to encode `CONTEXT_INFO` from `NVARCHAR(8)`, the controlled Customer Order process advanced beyond the previous `DeleteRemoteNotesSp` replication-rule error and returned:

```text
Error 50000 pada dbo.RaiseErrorSp line 121:
Tax Code that has [Tax System: 1] and [Tax Code Type: Rate]
and [Tax Code: TAX] and [Site: DEFAULT] ...
```

The user-provided message was truncated after `[Site: DEFAULT]`, so the exact final standard message text is not yet recorded.

## Confirmed interpretation

```text
Unicode site-context fix                  : EFFECTIVE
Previous replication blocker             : PASSED in this run
Current execution point                   : standard tax-code validation
Tax system                                : 1
Tax code type                             : Rate
Tax code                                  : TAX
Site                                      : DEFAULT
Customer Order rows created               : NOT CONFIRMED
```

The current blocker is tenant tax master data or the tax-code value supplied to `co_mst.tax_code1`. It must not be bypassed by disabling triggers.

## Next read-only step

Inspect the exact tax-code row and available active rate codes for site `DEFAULT`:

```sql
SELECT *
FROM dbo.stax_mst
WHERE site_ref = N'DEFAULT'
  AND tax_system = 1
  AND LTRIM(RTRIM(tax_code)) = N'TAX';

SELECT TOP (50)
    site_ref,
    tax_system,
    tax_code,
    description,
    tax_type,
    tax_rate
FROM dbo.stax_mst
WHERE site_ref = N'DEFAULT'
  AND tax_system = 1
ORDER BY tax_code;
```

Column names in the second query may need adjustment to the tenant schema if `description`, `tax_type`, or `tax_rate` differ. The first query is the authoritative existence check.
