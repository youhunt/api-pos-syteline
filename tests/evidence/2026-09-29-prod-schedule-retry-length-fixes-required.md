# PROD scheduler/retry table verification — length fixes still required

Date: 2026-09-29
Environment: PROD

Verification result:

```text
ScheduleTable                  PASS
ScheduleColumns25              PASS
ScheduleCodeNvarchar30         PASS
ScheduleNameNvarchar100        PASS
LastMessageNvarchar1000        FAIL
PrimaryKeySiteSchedule         PASS
RowPointerUniqueSemantic       PASS
ScheduleTriggers3              PASS
ScheduleEmptyBaseline          PASS
RetryLastErrorNvarchar1000     FAIL
```

Remaining corrections through SQL Tables:

```text
dbo.ue_SMK069_shipment_schedule_mst.LastMessage = nvarchar(1000)
dbo.ue_SMK069_shipment_retry_mst.LastError       = nvarchar(1000)
```

After changing each Length to 1000, use Update Current Table and rerun
deployment/shipment/prod/query-select/014-prod-schedule-retry-final-verify.sql.

Do not proceed to scheduler procedures until both checks PASS.
