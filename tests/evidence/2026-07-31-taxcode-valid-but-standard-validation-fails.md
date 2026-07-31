# Evidence — Valid Tax Code Still Rejected by Standard Validation

Date: 31 July 2026
Tenant database: `LENSA_SL_CSI_BAK`

## Tenant-confirmed facts

The controlled runtime still returns a standard tax-code error for:

```text
Tax System    : 1
Tax Code Type : Rate
Tax Code      : PPN11%
Site          : DEFAULT
```

However, tenant diagnostics confirmed:

```text
dbo.GetSiteContext() = DEFAULT
Database collation   = SQL_Latin1_General_CP1_CI_AS
```

`dbo.taxcode_mst` contains:

```text
site_ref       : Default
tax_system     : 1
tax_code_type  : R
tax_code       : PPN11%
description    : PPN 11%
tax_rate       : 11.00000
```

The site comparison against `dbo.GetSiteContext()` returned `SiteMatchesContext = 1`.

The standard view `dbo.taxcode` also exists and returns the same `PPN11%` row.

## Interpretation

The failure is not explained by:

```text
- missing PPN11% row
- missing dbo.taxcode view row
- incorrect site context
- Default versus DEFAULT case mismatch
```

The stored `error_msg` value is already truncated before XML rendering. The XML query concatenated multiple staging rows but did not recover the missing tail of the standard message.

The next investigation must inspect the executable tax-code validation predicate in `dbo.co_mstIup` or the exact standard routine it calls. Do not modify tax master data, disable triggers, or bypass standard validation before that predicate is known.
