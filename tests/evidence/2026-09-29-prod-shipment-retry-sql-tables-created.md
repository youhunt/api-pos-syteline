# PROD retry table — SQL Tables creation evidence

Date: 2026-09-29
Environment: PROD
Object: dbo.ue_SMK069_shipment_retry_mst

Observed from PROD SQL Tables UI:

- standard Mongoose columns are present;
- business columns visible: ShipmentId, AttemptCount, RetryState, FirstAttemptDate,
  LastAttemptDate, NextAttemptDate, LastHttpCode, LastError;
- Multi-Site is enabled;
- primary key is SiteRef + ShipmentId and is clustered/unique;
- RowPointer has a unique nonclustered constraint/index;
- due index exists on SiteRef + RetryState + NextAttemptDate;
- standard Mongoose triggers exist and are enabled:
  - ue_SMK069_shipment_retry_mstDel
  - ue_SMK069_shipment_retry_mstInsert (INSTEAD OF)
  - ue_SMK069_shipment_retry_mstUpdatePenultimate

Before scheduler activation, verify critical physical lengths/defaults and that the table is empty.
