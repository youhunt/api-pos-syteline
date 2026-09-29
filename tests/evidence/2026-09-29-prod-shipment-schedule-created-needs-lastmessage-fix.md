# PROD schedule table — SQL Tables creation evidence

Date: 2026-09-29
Environment: PROD
Object: dbo.ue_SMK069_shipment_schedule_mst

Observed from PROD SQL Tables UI:

- Multi-Site enabled;
- primary key on SiteRef + ScheduleCode;
- unique RowPointer index present;
- additional schedule index present;
- standard Mongoose triggers exist and are enabled:
  - ue_SMK069_shipment_schedule_mstDel
  - ue_SMK069_shipment_schedule_mstInsert (INSTEAD OF)
  - ue_SMK069_shipment_schedule_mstUpdatePenultimate
- 25 columns are present.

Correction required before scheduler procedures:
- LastMessage currently shows Length = 1 in SQL Tables.
- Current Shipment scheduler contract requires LastMessage nvarchar(1000).

Use SQL Tables to set:

```text
LastMessage Length = 1000
```

then Update Current Table and run the physical verification query.
