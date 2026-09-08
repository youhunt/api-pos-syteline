# Shipment Scheduler Assembly Naming Correction

Date: 2026-09-08

This note records the actual tenant naming confirmed from SyteLine screenshots and corrects earlier wording that conflated the IDO name with the Extension Class Assembly name.

## Confirmed tenant names

```text
Extension Class Assembly : ue_SMK069ShipmentExtensions
Service IDO              : ue_SMK069ShipmentTransport
Namespace                : SMK069Shipment
Extension Class          : SMK069ShipmentTransportExtension
Fully-qualified type     : SMK069Shipment.SMK069ShipmentTransportExtension
```

`ue_SMK069ShipmentTransport` is the IDO name. It is NOT the existing Extension Class Assembly name.

Do not create or select a new assembly named `ue_SMK069ShipmentTransport` just because the IDO has that name.

## Why the IDO Method Wizard error appeared

Observed message:

```text
Method 'SMK069RunDueShipmentSchedule' not found in type
'SMK069Shipment.SMK069ShipmentTransportExtension'.
```

This proves Mongoose successfully resolved the extension class type. The current problem is therefore not the namespace/class name. The method does not yet exist in the compiled class selected by the wizard, or the updated source has not been compiled into the existing assembly.

## Correct deployment sequence

1. Open existing assembly `ue_SMK069ShipmentExtensions`.
2. Open the source that contains `SMK069ShipmentTransportExtension`.
3. Confirm the class already contains revision-3 behavior, especially:
   - `SMK069SendPendingShipments`
   - `DN_No` handled as `String`
   - Infor -> POS `infor_dn` semantics
4. Paste the members from:

```text
extension-classes/SMK069ShipmentSchedulerRunner.snippet.cs
```

inside the SAME `SMK069ShipmentTransportExtension` class, before the class closing brace.
5. Save source.
6. Compile assembly `ue_SMK069ShipmentExtensions`.
7. Re-open IDO Method Wizard.
8. Choose assembly `ue_SMK069ShipmentExtensions` and class `SMK069Shipment.SMK069ShipmentTransportExtension`.
9. `SMK069RunDueShipmentSchedule` should now be discoverable.

## Important distinction

```text
Assembly  = ue_SMK069ShipmentExtensions
IDO       = ue_SMK069ShipmentTransport
Class     = SMK069ShipmentTransportExtension
Attribute = [IDOExtensionClass("ue_SMK069ShipmentTransport")]
```

The attribute binds the compiled class to the IDO; it does not define the assembly name.

## Do not use the stale source

`extension-classes/SMK069ShipmentSenderExtension.cs` in the repo is an older source snapshot and must not be used for scheduler rollout.

Use the current tenant source corresponding to `SMK069ShipmentSenderExtension.rev3.cs`, then merge the scheduler runner snippet into it and compile it under the existing assembly `ue_SMK069ShipmentExtensions`.
