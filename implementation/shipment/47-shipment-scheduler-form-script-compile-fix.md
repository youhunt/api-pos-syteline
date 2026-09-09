# Shipment Scheduler Form Script Compile Fix — Revision 3

Date: 2026-09-08

## Tenant symptom

After importing `FS_20260908_100718_dashboard_rev2.XML`, opening `ue_SMK069ShipmentScheduler` returned:

```text
Error compiling script ue_SMK069ShipmentScheduler->
```

The original tenant export did not contain a custom form script. Revision 2 introduced a VB.NET Form Script to implement status formatting and button actions.

## Probable compile causes in Revision 2

Inspection of the generated script found tenant-risky compile constructs, including:

1. `Option Strict On` while secondary collections were assigned through inferred/late-bound local variables.
2. `vbLf` was used while `Microsoft.VisualBasic` was not imported.
3. The script introduced a larger custom scripting surface than necessary for a form whose actions can be implemented with native Mongoose event-handler response types.

Without the tenant compiler's detailed error list, these are treated as probable causes rather than the only possible causes.

## Revision 3 artifacts

Two recovery variants were generated and XML-well-formed validation passed for both.

### A. Script-fixed variant

```text
FS_20260908_100718_dashboard_rev3.XML
```

Changes include:

- adds `Imports Microsoft.VisualBasic`
- uses explicit `IWSIDOCollection` declarations for secondary collections
- avoids ambiguous late-bound expressions under `Option Strict On`
- uses `Me.IDOClient.Invoke(...)`
- keeps the Revision 2 scripted button behavior

This variant still depends on the tenant form-script compiler.

### B. No-script recovery variant — preferred first test

```text
FS_20260908_100718_dashboard_rev3_noscript.XML
```

This removes the custom `<Script>` block entirely and keeps only the already-proven native collection refresh handlers:

```text
StdFormInitCompleted -> refresh object2 Dashboard
StdFormInitCompleted -> refresh object3 Queue
```

The redesigned dashboard layout remains, but script-driven action buttons are disabled so the form can be opened without compiling custom VB.NET.

## Preferred architecture after recovery

Once the no-script form opens correctly, wire the operator actions with native Mongoose event-handler response types rather than a custom form script where practical.

Required service-IDO control methods:

```text
SMK069SaveShipmentScheduleSp
SMK069SetShipmentSchedulerEnabledSp
SMK069RequestShipmentRunNowSp
SMK069ResetShipmentRetrySp
```

Target actions:

```text
Save Settings    -> Method Call -> SMK069SaveShipmentScheduleSp
Activate         -> Method Call -> SMK069SaveShipmentScheduleSp with IsEnabled=1
Deactivate       -> Method Call -> SMK069SaveShipmentScheduleSp with IsEnabled=0
Run Now          -> Method Call -> SMK069RequestShipmentRunNowSp
Enable Engine    -> Method Call -> SMK069SetShipmentSchedulerEnabledSp(1)
Disable Engine   -> Method Call -> SMK069SetShipmentSchedulerEnabledSp(0)
Reset Retry      -> Method Call -> SMK069ResetShipmentRetrySp
Refresh          -> native collection refresh for schedule/dashboard/queue
```

This reduces dependency on the form-script compiler and keeps the implementation closer to standard Mongoose form behavior.

## Security

The original UAT form export contained background-task credentials in an event response. Revision 2 and both Revision 3 artifacts remove that embedded task event/credential path. Credentials must not be stored in the form XML or repository.

## Recovery order

```text
1. Import FS_20260908_100718_dashboard_rev3_noscript.XML.
2. Open ue_SMK069ShipmentScheduler.
3. Confirm no script-compile error.
4. Confirm primary schedule, dashboard and queue still load.
5. Confirm the four control SP methods are registered on ue_SMK069ShipmentTransport.
6. Build native Method Call event handlers directly in the XML/form.
7. Re-export/import and UAT actions one at a time.
```
