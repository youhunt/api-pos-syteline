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

## Mapping-view source captured

The working DEV definition of:

```text
dbo.ue_SMK069_pos_sales_inbound_mapping_view
```

is now stored at:

```text
database/views/csv-to-co/ue_SMK069_pos_sales_inbound_mapping_view.sql
```

and embedded in `02-deploy-canonical-runtime.sql`.

The DEV SHA-256 remains recorded as audit evidence. The deployment source uses normalized `CREATE OR ALTER VIEW` text, so compare behavior/source markers rather than expecting the normalized PROD text hash to equal the historical DEV text hash byte-for-byte.

## Drift rule

If any canonical source blob above changes after this manifest, regenerate/re-audit:

```text
02-deploy-canonical-runtime.sql
```

before using it for production.


## DEV runtime baseline captured — 28 Sep 2026

The following SHA-256 values were captured in DEV using `OBJECT_DEFINITION` +
SQL Server `HASHBYTES('SHA2_256', CONVERT(VARBINARY(MAX), ...))`.

> These are **database-definition hashes**, not Git blob SHAs. Compare them
> only with the same SQL query in PROD.

| DEV object | type | modify date | definition SHA-256 |
|---|---|---:|---|
| `dbo.SMK069CsvSplitLine` | SQL_TABLE_VALUED_FUNCTION | 2026-08-28 | `3861E96211CA65047EC4E2CCE600D2B5CBAE7BA0EE89F8FD5818E3CA0044EB07` |
| `dbo.SMK069ImportCsvFileSp` | SQL_STORED_PROCEDURE | 2026-09-21 | `81F874475C2613BF96B6A27DD55119B2F78D95D361BE13BE05472E4619744C09` |
| `dbo.SMK069ProcessBatchCustomerOrdersSp` | SQL_STORED_PROCEDURE | 2026-09-16 | `D2A0B30A475D575B9AE0BA7A8A5160B88D4BF00235E3C04A7B5FD89BEC2F386D` |
| `dbo.SMK069ProcessCustomerOrderSp` | SQL_STORED_PROCEDURE | 2026-09-16 | `6E203E5CDCA12431C5BF3A1B8E5E06BE8DCD8F94A93BE8E884A1EB76B952EDD7` |
| `dbo.SMK069ReceivePosSalesJsonCoreSp` | SQL_STORED_PROCEDURE | 2026-09-23 | `3047D7D61E82AF2DCD359D76647340E5305C1F94BF5512BDD29B071C0E2D6CDA` |
| `dbo.SMK069ReceivePosSalesJsonSp` | SQL_STORED_PROCEDURE | 2026-09-23 | `9762F6D63149E34BD27B70FC925EE434A8B023398EC28D7E8AC39820BFB3C9EE` |
| `dbo.SMK069RunCsvTestBatchSp` | SQL_STORED_PROCEDURE | 2026-09-21 | `38C7890B4336EA804CE5D2A9B9625F0787E2FAD21E8F7D3C05AE577A35E7C472` |
| `dbo.SMK069ValidateCustomerSp` | SQL_STORED_PROCEDURE | 2026-07-30 | `020582BB95F84D21AF7DD30BE560B551727CF17E737A8696BBCDBF2B1211C21F` |
| `dbo.ue_SMK069_pos_sales_inbound_mapping_view` | VIEW | 2026-09-22 | `E1D32D405FE78D96259224E0D2EF78763E4216189A5F2222EE627228C75D1B0B` |

### PROD comparison rule

After migrating metadata/view/runtime to PROD, rerun the signature query in
PROD.

Use the hashes with two different rules:

1. **Exact-copy external objects** — especially the SMK/Eva-owned mapping view:
   the PROD hash **must match** the DEV hash when the exact DEV definition is
   migrated.
2. **Repository canonical runtime objects** deployed by
   `02-deploy-canonical-runtime.sql`: a DEV hash mismatch is **not by itself a
   failure**, because canonical source can differ textually from an incrementally
   patched DEV definition (comments, CREATE/ALTER text, formatting, rebased
   source) while implementing the same final behavior. Verify these objects with
   `03-post-deploy-verify.sql` and the canonical source manifest.

The most important strict hash gate is:

```text
dbo.ue_SMK069_pos_sales_inbound_mapping_view
DEV SHA-256:
E1D32D405FE78D96259224E0D2EF78763E4216189A5F2222EE627228C75D1B0B
```

If that view hash differs in PROD, stop functional cutover and compare the
definition before testing Peak/Normal mapping, `ValidationStatus`, item/U/M,
price, quantity conversion, or `cust_seq`.

The remaining DEV runtime hashes are retained as audit evidence and a useful
drift diagnostic, not as a mandatory byte-for-byte gate for the consolidated
canonical PROD deployment.
