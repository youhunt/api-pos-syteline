# SMK069 Test and Evidence Index

## Current End-to-End Scope

Primary test reference:

```text
docs/20-smk069-csv-to-blanket-customer-order-end-to-end.md
```

Final target pipeline:

```text
CSV
→ parse
→ Import & Validate
→ inbound
→ temp status V
→ Process/Reprocess
→ co_mst type B
→ coitem_mst
→ co_bln_mst
→ temp status P + created_co_num
```

## Current Correction Evidence

```text
tests/evidence/2026-08-06-smk069-um-validation-and-blanket-order-corrections.md
```

Covers:

- invalid U/M previously passed validation;
- required base U/M or U/M Conversion validation;
- atomic-order rejection;
- Blanket Customer Order requirement;
- `co_bln_mst.allow_on_pick_list = 0` correction;
- Mongoose outer-transaction/savepoint correction.

## Historical Evidence

Evidence dated 30 July through 3 August records development and successful regular Customer Order processing before the final Blanket Order requirement was introduced.

Important historical files include:

```text
tests/evidence/2026-08-03-smk069-cloud-e2e-customer-order-success.md
tests/evidence/2026-08-03-smk069-cloud-idempotent-reprocess-success.md
tests/evidence/2026-08-03-smk069-cloud-multiline-customer-order-success.md
```

These remain useful for customer, line, numbering, idempotency, and transaction history, but they are not final evidence for `co_bln_mst`.

## Required Final Evidence

### Happy Path

```text
[ ] CSV binary saved
[ ] Parsed detail rows visible
[ ] Import & Validate succeeds
[ ] Inbound rows become T
[ ] Temp rows become V
[ ] Process generates a SyteLine CO number
[ ] co_mst has one row and type B
[ ] co_mst.cust_po equals source/POS order
[ ] coitem_mst count equals temp count
[ ] co_bln_mst count equals temp count
[ ] co_bln_mst.allow_on_pick_list = 0
[ ] temp.created_co_num populated
[ ] temp.process_status = P
```

### U/M Negative Path

```text
[ ] U/M equals base U/M → valid
[ ] blank U/M with item base U/M → fallback and valid
[ ] different U/M with valid conversion → valid
[ ] different U/M without conversion → invalid
[ ] one invalid U/M line makes the whole source order invalid
[ ] invalid source order transfers zero rows to temp
```

### Transaction Path

```text
[ ] direct SQL call with no outer transaction
[ ] Mongoose/IDO call with outer transaction
[ ] coitem failure rolls back header
[ ] co_bln failure rolls back header and coitem lines
[ ] no transaction count mismatch error
[ ] original SQL/business error remains visible
```

### Volume Path

```text
[ ] 100 CSV rows
[ ] 25 distinct source orders
[ ] 4 lines per source order
[ ] 1 Receive call
[ ] 25 Process calls
[ ] 25 co_mst headers
[ ] 100 coitem_mst lines
[ ] 100 co_bln_mst lines
```

## Read-Only Verification

Use the queries in section `22. Read-Only Verification SQL` of:

```text
docs/20-smk069-csv-to-blanket-customer-order-end-to-end.md
```

Expected count reconciliation:

```text
staging line count = coitem_mst line count = co_bln_mst line count
co_mst header count = 1 per source order
```

## Repository Parity Check

Before final acceptance, export and compare the exact tenant source for:

```text
SMK069ImportCsvFileSp
SMK069ReceivePosSalesJsonSp
SMK069ProcessCustomerOrderSp
```

The committed SQL source and tenant source must match before the PR is merged as the implementation baseline.
