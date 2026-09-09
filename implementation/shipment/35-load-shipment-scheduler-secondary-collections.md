# Superseded — Secondary Collection Refresh Approach

Date: 2026-09-08
Form: `SMK069ShipmentScheduler`

This note is **superseded** by the corrected parent/child collection model documented in:

```text
implementation/37-keep-simple-shipment-scheduler-form-layout.md
```

The earlier approach treated Schedule as the primary collection and Dashboard / Queue as unrelated independent secondary collections that needed explicit form event refresh handlers.

That approach works conceptually, but it is unnecessarily awkward for this form and caused the current blank Dashboard / Queue behavior.

## Correct model

The data hierarchy is Site-based:

```text
SITE
├─ 1 Dashboard row
├─ N Schedule rows
├─ N Queue Shipment rows
└─ 1 SHIPMENT Config row
```

Therefore the preferred form collection model is:

```text
Primary/Parent : ue_SMK069ShipmentSchedulerDashboard
Child          : ue_SMK069ShipmentSchedules       (LinkBy SiteRef)
Child          : ue_SMK069ShipmentSchedulerQueue  (LinkBy SiteRef)
Child/optional : ue_SMK069ShipmentApiConfigs      (LinkBy SiteRef + filter ApiName='SHIPMENT')
```

Do **not** model Queue as a child of one Schedule. All schedules consume the same Site-level Shipment queue.

Do **not** create multiple Dashboard rows per Schedule. Dashboard is one summary row per Site.

Because the parent/child links can drive loading naturally, do not add `StdFormRefreshCompleted` handlers merely to compensate for the old independent-collection model unless the tenant later proves they are still needed.

Current UAT Site is `Default` and the verified baseline remains:

```text
Dashboard: Master=0, API Active=1, Ready=2, Waiting=0, Exhausted=0, Default Max=50
Queue    : P96327 READY, P96328 READY
Schedule : HOURLY / Every 60 Minutes / 60 / Enabled=0
```
