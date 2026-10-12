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
