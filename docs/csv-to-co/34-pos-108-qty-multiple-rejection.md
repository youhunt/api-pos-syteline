# 34 — POS-108 Quantity Multiple Rejection

> Date: 15 September 2026  
> Scope: CSV / POS inbound → Blanket Customer Order only

## Business decision

If an incoming order quantity is not a valid multiple after conversion to base U/M, the **whole `cust_po` is rejected before Customer Order creation**.

The tenant/business supplied validation formula is:

```sql
CAST
(
    ISNULL
    (
        dbo.SMK030_UomConvQty2
        (
            i.qty_ordered,
            ISNULL(dbo.Getumcf(i.u_m, ic.item, '', ''), 1),
            'To Base'
        ),
        0
    )
    AS decimal(23,5)
)
```

Invalid condition:

```sql
qty_base <> FLOOR(qty_base)
```

## Result code

Root offending line:

```text
[POS-108] Quantity tidak sesuai kelipatan U/M.
```

Other lines of the same `cust_po`:

```text
[POS-203] Order ditolak karena terdapat line lain yang tidak valid.
```

## Granularity

Validation is atomic per `cust_po`.

Example:

```text
PO-001 line 1 = valid
PO-001 line 2 = quantity invalid
PO-001 line 3 = valid

Result:
PO-001 rejected entirely; no CO is created.
```

If one API call later contains multiple POs:

```text
PO-001 valid       -> CO created
PO-002 POS-108     -> rejected
PO-003 valid       -> CO created
```

The batch is partial, but public API behavior remains `Success=false` when `@ThrowOnBusinessError = 1` because the API response is per invocation.

Current POS operational assumption is one API hit = one PO. Therefore POS-108 means the whole API call is rejected and no CO is created.

## Implementation point

Canonical entry point remains:

```text
dbo.SMK069ReceivePosSalesJsonSp
```

Flow:

```text
Receive JSON / CSV-built JSON
→ SMK069ReceivePosSalesJsonCoreSp
→ standard validation
→ POS-108 quantity-multiple validation
→ remove rejected PO V rows from temp
→ process remaining valid PO(s)
→ Blanket CO
```

The extra validation runs **after Core receive/validate but before Customer Order processing**. This lets the rule share one implementation for both public API JSON and CSV.

## Deployment

Apply:

```text
database/patches/csv-to-co/2026-09-15-smk069-18-reject-non-multiple-qty-per-po.sql
```

Patch properties:

```text
one executable batch
no GO
no IDO signature change
no new table/column
```

## API expected behavior — invalid single PO

Expected public result:

```text
Success = false
Message starts with [POS-108]
ProcessedOrders = 0
CreatedCoNums = empty
```

Representative message:

```text
[POS-108] Request ditolak. 1 baris bermasalah: [cust_po=PO-TEST-001] Quantity tidak sesuai kelipatan U/M [coline=2, item=..., qty_ordered=..., u_m=...] ProcessedOrders=0; ProcessErrors=0; SkippedOrders=0
```

## CSV expected behavior

CSV calls the same procedure with:

```text
@ThrowOnBusinessError = 0
```

For a single rejected PO, expected CSV batch state is:

```text
batch_status = E
validation_error_orders = 1
processed_orders = 0
process_error_orders = 0
result_message contains [POS-108]
```

## UAT checklist

1. Apply Patch 18.
2. Send a valid quantity/multiple PO; confirm CO still succeeds.
3. Send one PO containing one fractional converted-base quantity; confirm API returns `[POS-108]` and **no CO is created**.
4. Confirm all lines of that `cust_po` are inbound status `E`; root row is POS-108 and siblings POS-203.
5. Confirm rejected PO has no `V` staging rows left in `ue_SMK069_temp_sales_mst`.
6. Optional multi-PO test: one invalid PO must not prevent valid POs from becoming COs.

## Important SOP

- Fixing the source quantity means send a corrected order as a **new batch/request**.
- Do not create a new CO manually for the rejected request before the source system resends it unless the business explicitly authorizes that exception.
- Existing COs created before Patch 18 are not retroactively changed.
