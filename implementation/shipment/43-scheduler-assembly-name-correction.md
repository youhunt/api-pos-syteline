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

## Tenant evidence from the Method Wizard

The Method Name dropdown currently exposes:

```text
SMK069SendPendingShipments
SMK069SendOneShipmentKacs
SMK069SendOneShipment
SMK069PostShipmentPayload
```

This is important evidence:

1. the tenant is already using the revision that contains `SMK069SendPendingShipments`;
2. `SMK069ShipmentTransportExtension` is being discovered correctly;
3. `SMK069RunDueShipmentSchedule` is NOT in the compiled assembly yet.

Therefore do NOT attempt to manually type/register `SMK069RunDueShipmentSchedule` in the Method Wizard before compiling the runner into the existing assembly. The wizard can only expose methods that are present in the compiled extension type.

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

The snippet contains three members that must all be inside the class:

```text
public int SMK069RunDueShipmentSchedule(...)
private void ClaimDueShipmentSchedule(...)
private void CompleteShipmentSchedule(...)
```

Do NOT paste the snippet after the final class/namespace closing braces.

5. Save the source record. Make sure the source has a Filename and belongs to assembly `ue_SMK069ShipmentExtensions`.
6. Compile assembly `ue_SMK069ShipmentExtensions` and confirm compile success.
7. Close/re-open the IDO Method Wizard so it reads the newly compiled assembly metadata.
8. Choose assembly `ue_SMK069ShipmentExtensions` and class `SMK069Shipment.SMK069ShipmentTransportExtension`.
9. `SMK069RunDueShipmentSchedule` should now appear in the Method Name dropdown.
10. Only then create/register the IDO method metadata.

## If the method is still missing after compile

Check these in order:

```text
1. Search source for exact text: SMK069RunDueShipmentSchedule
2. Verify it is inside class SMK069ShipmentTransportExtension
3. Verify it is declared public
4. Verify it has [IDOMethod(MethodFlags.None, "Infobar")]
5. Verify the edited source belongs to assembly ue_SMK069ShipmentExtensions
6. Verify assembly compile completed successfully after the edit
7. Close and reopen IDO Method Wizard
```

If `SMK069SendPendingShipments` appears but `SMK069RunDueShipmentSchedule` still does not, the runner source has not made it into the compiled assembly being inspected.

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
