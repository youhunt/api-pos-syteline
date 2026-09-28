# SMK069 PROD — Turnkey Cutover

**Prepared:** 28 September 2026  
**Scope:** CSV / POS inbound → Blanket Customer Order only

## Goal

Reduce PROD migration to two supported deployment channels:

1. **Mongoose metadata import**
2. **One Apply Database SQL**

A single SQL file should **not** be used to write Mongoose metadata tables directly.
Forms, IDOs, UET classes, form events and generated table triggers are
application metadata and should be migrated using Mongoose-supported
export/import/metadata tooling.

## A. Core physical tables — create first

Run:

```text
deployment/csv-to-co/prod/00c-create-core-physical-tables.sql
```

This creates the four DEV-proven transaction/staging tables, including their
captured identities, keys, indexes, defaults and CSV batch/detail foreign key.

## B. Mongoose metadata package

Export the verified working DEV metadata for:

```text
UET
- Uf_SMK069_is_peak_season
- Uf_SMK069_pos_um
- SMK069_CL_itemcust
- itemcust_mst extension

Tables / Entity IDOs
- ue_SMK069_pos_sales_inbound_mst metadata
- ue_SMK069_temp_sales_mst metadata
- ue_SMK069_pos_csv_batch_mst metadata
- ue_SMK069_pos_csv_upload_mst metadata
- ue_SMK069TempSales
- ue_SMK069PosCsvUpload

IDO methods
- public SMK069ReceivePosSalesJsonSp method
- SMK069RunCsvTestBatchSp
- validation / process methods used by Error Processing
- Transactional=False on the public Receive/process orchestration methods

Forms
- ue_SMK069APISalesErrorProcessing
- ue_SMK069PosCsvBatchConsole
- Customer Contracts custom components for POS U/M / Peak Season
```

After import, run Apply/Impact Schema so Mongoose creates/regenerates the
physical custom tables, user fields and generated triggers consistently.

## C. One Apply Database SQL

After metadata/schema exists, run:

```text
deployment/csv-to-co/prod/02-deploy-canonical-runtime.sql
```

This file deploys current-state SQL runtime including:

```text
dbo.ue_SMK069_pos_sales_inbound_mapping_view
dbo.SMK069CsvSplitLine
dbo.SMK069ImportCsvFileSp
dbo.SMK069ValidateCustomerSp
dbo.SMK069ProcessCustomerOrderSp
dbo.SMK069ProcessBatchCustomerOrdersSp
dbo.SMK069ReceivePosSalesJsonCoreSp
dbo.SMK069ReceivePosSalesJsonSp
dbo.SMK069RunCsvTestBatchSp
```

No numbered DEV patch replay is required.

## Why metadata is separate

The DEV physical schema contains Mongoose-generated columns and data types such
as:

```text
UsernameType
CurrentDateType
RowPointerType
SiteType
CustNumType
CoNumType
CoLineType
CostPrcType
QtyUnitType
UMType
WhseType
```

and generated trigger behavior. Creating only physical SQL tables would not
create the full Mongoose metadata contract used by IDOs/forms.

Therefore direct SQL table creation is not the authoritative production path
for these Mongoose-owned custom objects.

## What no longer needs manual reconstruction

The mapping view is now captured in source control:

```text
database/views/csv-to-co/ue_SMK069_pos_sales_inbound_mapping_view.sql
```

Peak/Normal mapping, ValidationStatus, customer mapping, item/U/M, quantity,
price, warehouse, due date, terms and tax projection are included in the
canonical SQL runtime package.

## Minimal PROD sequence

```text
1. Run 00c-create-core-physical-tables.sql
2. Import verified DEV UET metadata
3. Run UET Impact Schema
4. Verify itemcust physical fields (optional Query Select 00f)
5. Import remaining verified DEV IDO/Form metadata
6. Run 01-preflight.sql
7. Run 02-deploy-canonical-runtime.sql in Apply Database
8. Run 03-post-deploy-verify.sql
9. Run smoke/UAT checklist
```

If speed is critical, steps 3 and 5 are validation gates; they do not create
business objects. They are retained to catch incomplete metadata migration
before production traffic is opened.

## Definition of "ready to apply"

The migration can be considered turnkey when the repository contains:

```text
[x] canonical current-state SP/function sources
[x] canonical mapping view
[x] PROD one-batch SQL runtime
[x] schema contract/preflight
[x] verification queries
[x] UAT runbook
[ ] exact DEV Mongoose metadata export package(s)
```

The remaining item is an export artifact, not missing business logic.


## Direct itemcust SQL fallback

`00e-ensure-itemcust-peak-posum-physical.sql` is retained only as a controlled
fallback. The verified normal deployment path is Mongoose UET metadata import
followed by UET Impact Schema.
