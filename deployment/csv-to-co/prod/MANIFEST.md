# SMK069 PROD Migration Manifest

**Prepared:** 24 September 2026  
**Repository:** `youhunt/api-pos-syteline`

The consolidated PROD runtime file was generated from the following canonical repository blobs:

| Canonical source | Git blob SHA |
|---|---|
| `database/procedures/csv-to-co/SMK069ReceivePosSalesJsonCoreSp.sql` | `e37001f0ee216b52ea82fdfd51dfca88387f4c2e` |
| `database/procedures/csv-to-co/SMK069ReceivePosSalesJsonSp.sql` | `c7947359e88ff96d5abc6876c7908f52cc14f765` |
| `database/procedures/csv-to-co/SMK069ProcessBatchCustomerOrdersSp.sql` | `cc9f1b92ce478e7fa9b7cf7ccdd9f6f8bbd6ebcf` |
| `database/procedures/csv-to-co/SMK069ProcessCustomerOrderSp.sql` | `02241c8562c882444f9f4493e61b0998ea11f2d5` |
| `database/procedures/csv-to-co/SMK069RunCsvTestBatchSp.sql` | `430172d448f1ce13e3437ba1bc3be3c2f3dc1f26` |
| `database/stored-procedures/csv-to-co/SMK069ImportCsvFileSp.sql` | `3374152e08eed2eb5c850bc6a790644f2c5ba15d` |
| `database/stored-procedures/csv-to-co/SMK069ValidateCustomerSp.sql` | `76f2888b2f3318e4e8c9f7fa80c7646d723a1a68` |

Generated production artifacts:

| Artifact | Purpose |
|---|---|
| `00-capture-dev-baseline.sql` | Capture DEV definitions, hashes, schema and triggers |
| `01-preflight.sql` | Fail-fast PROD dependency/schema gate |
| `02-deploy-canonical-runtime.sql` | One-batch current-state runtime deployment; NO GO |
| `03-post-deploy-verify.sql` | Read-only source-contract verification |
| `04-mongoose-metadata-checklist.md` | UET/IDO/Form migration |
| `05-prod-uat-checklist.md` | PROD functional/UAT sign-off |
| `README.md` | Migration runbook |

## Deliberately excluded from consolidated runtime

```text
database/patches/csv-to-co/*
```

The numbered patch directory is retained as DEV/UAT history and upgrade evidence.

In particular:

```text
2026-09-23-smk069-32-reject-cross-batch-duplicate-custpo.sql
```

is **WITHDRAWN / DO NOT APPLY**.

## External definition not embedded

```text
dbo.ue_SMK069_pos_sales_inbound_mapping_view
```

is owned by Eva / SMK and must be migrated from the exact working DEV definition. Record its DEV SHA-256 from `00-capture-dev-baseline.sql`, then compare it with PROD after import.

## Drift rule

If any canonical source blob above changes after this manifest, regenerate/re-audit:

```text
02-deploy-canonical-runtime.sql
```

before using it for production.
