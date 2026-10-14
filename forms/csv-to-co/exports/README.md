# CSV-to-CO Form Exports

This folder stores exact Mongoose FormsAndObjects exports used for TRN → PRD parity.

## Current files

~~~text
ue_SMK069APISalesErrorProcessing-TRN-2026-10-12.xml
ue_SMK069APISalesErrorProcessing-PRD-before-history-2026-10-12.xml
~~~

## Migration rule

Use the verified TRN export as the source for PRD after dependent SQL/IDO objects
exist.

The PRD-before-history export is retained only as rollback/diff evidence.

The TRN export contains the History tab, object2 secondary collection,
RefreshHistory event, and standard-form refresh hook.

Do not import the TRN form before:

~~~text
dbo.ue_SMK069_pos_sales_inbound_hist
dbo.ue_SMK069_pos_sales_inbound_history_v
ue_SMK069PosSalesInboundHistory
~~~

are available in PRD.

## SMK POS CSV TO BLANKET CO (14 Oct 2026)

~~~text
ue_SMK069PosCsvBatchConsole-DEV-before-urgent-2026-10-14.xml   (export DEV apa adanya, rollback/diff)
ue_SMK069PosCsvBatchConsole-DEV-urgent-2026-10-14.xml          (+ kolom grid Is Urgent dan Urgent Remark)
~~~

The second file differs from the first only by two new read-only grid columns (`gridColumnIsUrgent`, `gridColumnUrgentRemark`) placed right after Is Peak Season, and `ContainerSequence` +2 for the columns that follow. Import it only after Patch 37 is applied and IDO `ue_SMK069PosCsvUpload` has been resynchronized (properties `IsUrgent`, `UrgentRemark`). See `forms/csv-to-co/04-SMK069PosCsvBatchConsole-Urgent.md`.
