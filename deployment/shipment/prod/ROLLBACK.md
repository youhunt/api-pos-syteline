# Shipment PROD — Rollback / Emergency Stop

Prepared: 2026-09-24

Rollback priority is to **stop new outbound sends without deleting evidence**.

## Immediate stop

Preferred:

```text
SMK Shipment Scheduler Control Center
→ STOP SCHEDULER
→ REFRESH STATUS
```

If the form is unavailable or too slow, execute:

```text
deployment/shipment/prod/apply-database/090-emergency-stop.sql
```

This turns off:

```text
ue_SMK069_shipment_api_config_mst.SchedulerEnabled
ue_SMK069_shipment_schedule_mst.IsEnabled
RunRequested
```

It does not delete API/retry history.

## TaskMan

If the recurring task is WAITING, STOP can remove it.

If status is READY/RUNNING:

1. keep master/business gates OFF;
2. do not hard-delete an in-flight task;
3. let the invocation finish;
4. refresh until WAITING;
5. STOP again to remove the recurrence.

## Preserve evidence

Do not delete or reset as part of rollback:

```text
ue_SMK069_shipment_api_log_mst
ue_SMK069_shipment_retry_mst
Last Run values
response body / HTTP code
```

Use those records to determine whether a DN reached POS before any manual replay.

## Configuration rollback

Do not switch back to UAT URLs in PROD.

If PROD URL/credential is wrong, keep scheduler OFF, correct the PROD configuration/credential locally, then repeat the controlled one-DN smoke test.

## Database object rollback

The PROD migration SQL is additive/tenant-preserving. Do not blindly drop new tables, views, or procedures after a failed smoke test.

Restore an object definition only from a pre-cutover PROD export/backup and only when the object itself is proven to be the cause.

## Resume after rollback

Resume only after:

```text
root cause fixed
post-deploy Query Select PASS
Shipments / Run = 1
one controlled RUN ONCE PASS
no duplicate ActiveBGTasks
```

Then START SCHEDULER and confirm a new PROD TaskNumber.
