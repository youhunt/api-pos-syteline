# PROD ue_SMK069ShipmentTransport method surface PASS

Date: 2026-09-30
Environment: PROD
IDO: ue_SMK069ShipmentTransport

Observed registered methods:

Stored Procedure - Standard Method:
- SMK069ClaimDueShipmentScheduleSp
- SMK069CompleteShipmentScheduleSp
- SMK069CompleteShipmentSendSp
- SMK069GetPendingShipmentsSp
- SMK069GetShipmentConfigSp
- SMK069PrepareShipmentSendSp
- SMK069RecordShipmentAttemptSp
- SMK069RequestShipmentRunNowSp
- SMK069ResetShipmentRetrySp
- SMK069SaveShipmentScheduleSp
- SMK069SetShipmentSchedulerEnabledSp

Extension Class - Standard Method:
- SMK069PostShipmentPayload
- SMK069RunDueShipmentSchedule
- SMK069SendOneShipment
- SMK069SendOneShipmentKacs
- SMK069SendPendingShipments

All methods are Transactional=0, which is appropriate for the external HTTP shipment runtime.

Interpretation:
- the PROD service IDO method surface matches the current TRN Shipment service surface needed by the scheduler and sender;
- extension-method metadata is present;
- this does not by itself prove the referenced custom assembly has been imported/compiled successfully in PROD. Runtime/assembly verification is still required before any real Shipment send.
