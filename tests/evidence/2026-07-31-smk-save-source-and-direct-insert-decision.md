# Evidence — SMK_Save Source and Direct-Insert Decision

Date: 31 July 2026

## Tenant Form

```text
CustomerOrdersQuickEntry
```

## SMK_Save Source Result

The user provided the complete `SMK_Save()` form-script method. The method only evaluates the custom request-date property and changes `Stat` to `S` when the request date is more than 30 days in the past.

Relevant behavior:

```text
Read coUf_SMK025_Req_Date
→ calculate day difference from current date
→ when result < -30
→ set Stat = S
```

The method does not:

```text
- build JSON;
- encode Base64;
- invoke SL.SLCos.CreateCoAndLines;
- insert Customer Order header or lines;
- call another Customer Order helper.
```

Therefore `SMK_Save()` is not a source for the undocumented `CreateCoAndLines` payload contract.

## User Decision

The user explicitly decided to stop the `CreateCoAndLines` discovery path because it was taking too long and to proceed with a stored-procedure/direct-insert implementation for delivery speed.

Active target flow:

```text
ue_SMK069_temp_sales_mst
→ controlled stored procedure
→ dbo.co_mst
→ dbo.coitem_mst
→ update staging status
```

## Required Safety Boundary

```text
- Keep triggers enabled.
- Keep constraints enabled.
- Use SET XACT_ABORT ON.
- Use one explicit transaction for header, lines, and staging status.
- Roll back the complete order on any failure.
- Prevent duplicate processing/reprocessing.
- Do not commit a header without all required lines.
```

## Current Missing Input

The existing header procedure is available, but the tenant-specific `coitem_mst` insert mapping or previous line-insert procedure has not yet been provided. That mapping is the next required implementation input.
