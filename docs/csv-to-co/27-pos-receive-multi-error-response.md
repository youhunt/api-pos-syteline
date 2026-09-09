# 27 — Multi-Error Response for POS Receive

> **Date:** 7 September 2026
> **Raised by:** POS team, during UAT of `SMK069ReceivePosSalesJsonSp`
> **Related:** `docs/26-partial-success-and-csv-to-customer-order.md` — same defect class, different wrapper
> **Patch:** `database/patches/2026-09-07-smk069-04-public-receive-multi-error.sql`
> **Status:** written, pending Apply Database and UAT — see §8

* * *

## 1. The request

> "Saya hit API dengan isi 5 material, ternyata 2 material tidak terdaftar,
> maka keluarkan 2 material itu yang tidak terdaftar."

One API call must report **every** invalid material, not the first one. Today the
integrator fixes one item, calls again, discovers the next, and repeats — one
round trip per bad row.

* * *

## 2. Reproduction

Payload — three lines, one `cust_po`:

```json
["POS","DEV4-202",
 "[{\"custnum\":\"DEV4\",\"order_date\":\"2026-09-04\",\"cust_po\":\"DEV4-202\",\"whse\":\"P963\",\"coline\":1,\"item\":\"AA00015C\",\"qty_ordered\":144,\"u_m\":\"PCS\"},
   {\"custnum\":\"DEV4\",...,\"coline\":2,\"item\":\"AA00024C\",\"qty_ordered\":180,\"u_m\":\"PCS\"},
   {\"custnum\":\"DEV4\",...,\"coline\":3,\"item\":\"AH00034A\",\"qty_ordered\":10,\"u_m\":\"KG\"}]",
 "POS_API",null,null,null,null,null,null]
```

Response:

```json
{
  "Message": "[POS-101] Request ditolak [cust_po=DEV4-202]. Data payload tidak terdaftar atau tidak sesuai di Infor [coline=1, custnum=DEV4, item=AA00015C, u_m=PCS, whse=P963]:dbo.SMK069ReceivePosSalesJsonSp:183",
  "Success": false,
  "Parameters": null,
  "ReturnValue": null
}
```

Only `AA00015C` is named. `AH00034A` surfaced only after the first item was
removed from the payload.

* * *

## 3. Root cause

**`Parameters: null` and `ReturnValue: null` are the signature of `THROW`.**
The T-SQL batch is aborted, so every OUTPUT parameter is discarded — including
`@Infobar`, which already held the full list.

`SMK069ReceivePosSalesJsonCoreSp` step 13 collects up to ten errors:

```sql
SELECT @ErrorDetail = STUFF((
    SELECT TOP (10)
        N' | Row ' + CONVERT(NVARCHAR(20), e.row_no)
        + CASE WHEN NULLIF(LTRIM(RTRIM(e.cust_po)), N'') IS NULL THEN N''
               ELSE N' [cust_po=' + LTRIM(RTRIM(e.cust_po)) + N']' END
        + N': ' + COALESCE(NULLIF(LTRIM(RTRIM(e.validation_msg)), N''), N'Validation error.')
    FROM dbo.ue_SMK069_pos_sales_inbound_mst AS e
    WHERE e.SiteRef = @Site
      AND e.source_system = @SourceSystem
      AND e.batch_id = @BatchId
      AND e.inbound_status = N'E'
    ORDER BY e.row_no
    FOR XML PATH(N''), TYPE).value(N'.', N'NVARCHAR(MAX)'), 1, 3, N'');
```

and appends it to `@Infobar` as `ErrorDetail: …`.

`SMK069ReceivePosSalesJsonSp` then takes `SELECT TOP (1)` from the same table,
builds a single-item message, and throws it at line 183. The complete list is
computed on every call and thrown away on every call.

**Nothing needs to be discovered or added. The wrapper only has to stop
narrowing what Core already produced.**

This is the same defect class documented in `docs/26` §3 — an engine that works
per row, wrapped by a procedure that reduces the result to one outcome. Fixed
there for `SMK069ReceiveAndProcessPosSalesJsonSp` and `SMK069RunCsvTestBatchSp`;
`SMK069ReceivePosSalesJsonSp` is the third and last instance, and the only one
that faces an external integrator.

* * *

## 4. The change, as implemented

Patch: `database/patches/2026-09-07-smk069-04-public-receive-multi-error.sql`

Target: `dbo.SMK069ReceivePosSalesJsonSp` only. The signature is unchanged — all
ten parameters keep their positions, so no IDO method metadata change is needed
and the Postman collection keeps working.

**`SMK069ReceivePosSalesJsonCoreSp` is not modified.** The wrapper composes its
message directly from `ue_SMK069_pos_sales_inbound_mst`, so Core's `TOP (10)`
cap governs only Core's own `@Infobar` — which `THROW` discards anyway. Raising
it would change nothing that the caller can see.

1. **`SELECT TOP (1)` replaced by a `FOR XML PATH` aggregate** over every
   offending row. The friendly per-code descriptions for `POS-102`, `POS-104`,
   `POS-105` and `POS-106`, and the `POS-101` fallback, are preserved verbatim;
   only the number of rows changes. A `POS-103` branch was added so an
   unregistered material reads as such instead of falling through to the
   generic text.

2. **Atomic-order sibling rows are filtered out** when the batch contains at
   least one real error. Those rows carry `[POS-203]` and are lines that are
   themselves valid — listing them would bury the materials the caller actually
   has to fix. If a batch somehow contains nothing but `POS-203` rows, the
   filter is skipped so the response is never empty.

3. **The message is prefixed with the offending row count** and, when it exceeds
   the `THROW` limit, truncated with an explicit note naming the true total.

### What deliberately did not change

`THROW 51069` is kept. Business failure still surfaces as `Success: false` with
the text in `Message`, exactly as today, **so the POS integrator needs no change
on their side to benefit from this patch.**

Two consequences carry over unchanged:

- `Parameters` and `ReturnValue` stay `null`, so the counts
  (`ReceivedRows`, `TotalOrders`, `ValidOrders`, `ErrorOrders`,
  `TransferredRows`) still do not reach the caller;
- the list is capped by the 2048-character `THROW` message limit — roughly a
  dozen materials.

Lifting both means replacing `THROW` with `RETURN 16` and reading the outcome
from `Parameters` instead of `Message`. That changes how the integrator detects
failure, so it is deliberately held back for a separate patch agreed with the
POS team first. §5 shows what that response would look like.

## 5. Response before and after

Before:

```json
{"Message":"[POS-101] Request ditolak [cust_po=DEV4-202] ... item=AA00015C ...",
 "Success":false,"Parameters":null,"ReturnValue":null}
```

After:

```json
{"Message": null,
 "Success": true,
 "Parameters": ["POS","DEV4-202","[...]","POS_API","3","1","0","1","0",
   "[POS-000] Batch DEV4-202 diterima. Row: 3; order(cust_po): 1; valid: 0; error: 1; row masuk temp: 0. ErrorDetail: Row 1 [cust_po=DEV4-202]: [POS-101] Data payload tidak terdaftar atau tidak sesuai di Infor [custnum=DEV4, item=AA00015C, u_m=PCS, whse=P963, coline=1] | Row 2 [cust_po=DEV4-202]: [POS-203] Order ditolak karena terdapat line lain yang tidak valid. | Row 3 [cust_po=DEV4-202]: [POS-101] Data payload tidak terdaftar atau tidak sesuai di Infor [custnum=DEV4, item=AH00034A, u_m=KG, whse=P963, coline=3]"],
 "ReturnValue": "16"}
```

`Success: true` is the Mongoose transport envelope — it means the method
executed, not that the batch was accepted. The business outcome is
`ReturnValue` plus the counts. This is the same convention
`SMK069RunCsvTestBatchSp` has always used, so it is not a new idea being
introduced to the integrator, only one being applied consistently.

Row 2 appears with `[POS-203]` because all three lines share one `cust_po` and
the atomic order rule rejects the whole order when any line is invalid. That is
existing, intended behaviour — see Core step 8.

* * *

## 6. What this does not fix

**`[POS-101]` still cannot name the offending field.** It is raised when the
canonical mapping view returns no row at all; the join failed, so `custnum`,
`item`, `u_m` and `whse` are all suspects and the message lists them together.
When the view *does* return a row and a column is empty, Core is already
precise: `POS-102` customer, `POS-103` item, `POS-104` U/M, `POS-105` price,
`POS-106` warehouse, `POS-107` customer sequence.

If the POS team needs *why* and not only *which*, that is a separate change in
the mapping view — it would have to expose per-key match flags rather than
relying on an inner join. Do not fold it into this patch.

For `AA00015C` with `u_m = PCS`: earlier UAT used `CTN` for that item. Worth
confirming with the POS team whether the item is unregistered, or whether the
item plus U/M combination is missing from the customer-item master. `POS-101`
cannot distinguish the two.

* * *

## 7. Incidental finding — POS warehouse codes resolve

The payload used `whse = P963`, and line 2 (`AA00024C`) validated successfully.
So the canonical mapping view already translates POS-side warehouse codes; it is
not limited to SyteLine codes such as `MAIN`.

This is a lead for the open Shipment issue in
`docs/24-smk069-current-handoff-2026-09-03.md` §17, where `WHS_CODE` is sent to
KACS as the raw SyteLine value `PLG` and the payload is rejected with
`1009 Invalid params`. The SyteLine ↔ POS warehouse translation appears to exist
already inside `ue_SMK069_pos_sales_inbound_mapping_view`; the outbound Shipment
view does not use it. Verify with:

```sql
SELECT DISTINCT whse
FROM dbo.ue_SMK069_pos_sales_inbound_mapping_view
WHERE SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));
```

If that returns SyteLine codes while the payload sent `P963`, the translation is
in the view and the reverse direction is available for Shipment.

* * *

## 8. Status

The tenant source arrived on 7 September 2026 and confirmed that
`SMK069ReceivePosSalesJsonSp` is a pure wrapper: it calls Core, then composes an
error message. There is no additional business logic in the "Public Receive
V2.4.8" package that a `CREATE OR ALTER` would overwrite.

Patch 04 is written and ready to apply:

```text
database/patches/2026-09-07-smk069-04-public-receive-multi-error.sql
```

Before Apply Database, capture the current definition so the repository finally
holds the tenant truth and a rollback is possible:

```sql
SELECT definition FROM sys.sql_modules
WHERE object_id = OBJECT_ID('dbo.SMK069ReceivePosSalesJsonSp');
```

### UAT

Re-send the exact `DEV4-202` payload from §2. Expected: a single response whose
`Message` names both `AA00015C` and `AH00034A`, with `AA00024C` absent because
it is a valid line rejected only by the atomic-order rule.

Then confirm the single-error case still reads cleanly — a payload with one bad
material must not gain noise from the new row-count prefix.

### Follow-up, not in this patch

- `RETURN 16` instead of `THROW`, so the counts and an uncapped list reach the
  caller. Needs the POS team to change how they detect failure.
- A structured `@ErrorsJson` output for machine consumption, appended with a
  default the way `@CreatedCoNums` was in the 4 September patches. Only useful
  once the procedure returns instead of throwing.
