# 18 — Customer Order Processing Handoff

## Current Status

```text
Environment                         : DEV / Infor Cloud tenant
CreateCoAndLines discovery          : PAUSED BY USER
Active implementation path          : controlled stored procedure / direct insert
Target header table                 : dbo.co_mst
Target line table                   : dbo.coitem_mst
Staging table                       : dbo.ue_SMK069_temp_sales_mst
Existing header procedure           : dbo.InsertCO
Header procedure reuse              : partial, with safety refactor
Tenant line insert mapping          : still required
```

## Why the Standard-Method Path Was Paused

The tenant confirmed `SL.SLCos.CreateCoAndLines` requires a Base64-encoded JSON object, but the exact business schema was not available. Controlled probes and metadata/form searches did not reveal a valid payload contract.

`CustomerOrdersQuickEntry` confirmed the standard data model:

```text
oSLCos / SLCos
└── oLines / SLCoitems
```

Its custom `SMK_Save()` source was inspected and proved unrelated to Customer Order creation; it only changes order status for a backdated custom request date.

## Active Processing Contract

```text
staging order rows
→ validate one order and one site
→ begin transaction
→ insert co_mst
→ insert every coitem_mst line
→ update staging to P
→ commit
```

Failure:

```text
rollback complete order
→ staging status E
→ store error_msg
→ retry_count + 1
```

## Required Safety Controls

```text
SET XACT_ABORT ON
TRY/CATCH and explicit transaction
triggers remain enabled
constraints remain enabled
no partial header/line commit
idempotency and reprocess protection
customer/item/site validation
cost retrieval from master data
header total = SUM(unit_price * qty_ordered)
```

## Next Step Only

Obtain the previous tenant-specific line insertion implementation for `dbo.coitem_mst`, preferably:

```text
InsertCOItem / InsertCoLine stored procedure
```

or its direct `INSERT INTO coitem_mst` code.

Do not guess mandatory line fields and do not execute the old header procedure with triggers or constraints disabled.

## Evidence

```text
tests/evidence/2026-07-31-smk-save-source-and-direct-insert-decision.md
```
