# Shipment PROD metadata scope guard

Updated: 2026-09-30

This cutover is Shipment outbound only. Do not migrate CSV-to-CO / POS inbound
objects merely because they share the SMK069 prefix.

## Shipment allowlist

IDO / runtime metadata allowed for this cutover:

```text
ue_SMK069ShipmentTransport
ue_SMK069ShipmentApiConfigs
ue_SMK069ShipmentSchedules
ue_SMK069ShipmentRetries
ue_SMK069ShipmentApiLogs
ue_SMK069ShipmentSchedulerDashboard
ue_SMK069ShipmentSchedulerQueue

Assembly:
ue_SMK069ShipmentExtensions

Form:
ue_SMK069ShipmentScheduler

Background Task Definition:
SMK069ShipmentScheduler

Built-in runtime read source:
ActiveBGTasks
```

Shipment SQL objects allowed include only the documented
`SMK069_ShipmentAPI_mst`, Shipment Build/Prepare/Complete procedures, Shipment
scheduler procedures/views, and `ue_SMK069_shipment_*` tables used by this
module.

## Explicitly out of scope / reject if accidentally included

Examples of CSV-to-CO / POS inbound objects that must not be imported as part of
this Shipment cutover:

```text
ue_SMK069TempSales
ue_SMK069PosCsvUpload
ue_SMK069APISalesErrorProcessing
ue_SMK069PosCsvBatchConsole
dbo.ue_SMK069_temp_sales_mst
dbo.ue_SMK069_pos_csv_*
dbo.ue_SMK069_pos_sales_inbound_*
SMK069ReceivePosSalesJsonSp
SMK069ImportCsvFileSp
SMK069ValidateCustomerSp
SMK069ProcessCustomerOrderSp
SMK069ProcessBatchCustomerOrdersSp
```

If an export/import package contains any non-allowlisted SMK069 object, stop and
review it before importing. Shared prefix is not sufficient evidence that the
object belongs to Shipment.
