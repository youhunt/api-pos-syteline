# Clean PROD SQL runtime run list — Shipment

Updated: 2026-09-29

This is the reduced run list for the current clean PROD migration after the exact
current UAT baseline objects and Mongoose-owned tables have already been created
and verified.

## Already satisfied — do not replay

```text
010..016 config-column ALTERs
017      retry table raw DDL
030      schedule table raw DDL
050      Prepare DN patch
060      DOC_NO patch
061      Complete DN patch
071      STORE_ORDER_NO patch
072      retry-policy patch
073      PRICE patch
```

Reason:

- config table already has the final 24-column contract;
- retry/schedule tables were created through SQL Tables and verified;
- current Build/Prepare/Complete baselines already contain the required fixes;
- final PROD config file 080 sets retry=1 minute, MaxAttempts=1440 and creates or
  normalizes HOURLY to Every 1 Minute / MaxShipments=1 / OFF, so 031 and 072 are
  not required for this clean-PROD path.

## Apply now, one Apply Database execution per file

```text
020-get-shipment-config-sp.sql
021-get-pending-shipments-sp.sql
022-record-shipment-attempt-sp.sql

032-get-scheduler-dashboard-sp.sql
033-save-schedule-sp.sql
034-set-scheduler-enabled-sp.sql
035-request-run-now-sp.sql
036-reset-retry-sp.sql
037-claim-due-schedule-sp.sql
038-complete-schedule-sp.sql

040-dashboard-view.sql
041-queue-view.sql

070-run-once-bypass.sql
```

Do not run 080 until the real PROD LoginUrl and Shipment EndpointUrl have been
confirmed and substituted.

Do not START scheduler or RUN ONCE during this stage.
