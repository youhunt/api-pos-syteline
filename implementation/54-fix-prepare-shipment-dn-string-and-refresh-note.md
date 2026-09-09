# SMK069 Shipment - Prepare DN string fix and dashboard refresh note

Date: 2026-09-09

## Tenant evidence

Runtime scheduler batch attempted DN `P96330` and `P96331` and failed before HTTP with:

```text
Prepare Shipment exception: IDOValueType.GetValue: failed to parse normalized string [P96330], Type = Int64
```

Tenant `sys.parameters` confirmed the mismatch:

```text
SMK069PrepareShipmentSendSp  @DN_No  bigint
SMK069BuildShipmentJsonSp    @DN_No  nvarchar
```

This explains HTTP code `0`: the failure is in the Prepare stage before the Shipment POST.

## Patch

Apply:

```text
database/patches/2026-09-09-smk069-11-fix-prepare-shipment-dn-string.sql
```

The patch reads the installed tenant definition of `dbo.SMK069PrepareShipmentSendSp`, preserves the existing body, and changes only the first parameter declaration from `BIGINT` to `NVARCHAR(40)`.

It is intentionally a single executable batch without `GO` so it can be used through Infor Apply Database.

## Required IDO metadata step

After applying Patch 11:

1. Open IDO `ue_SMK069ShipmentTransport`.
2. Select method `SMK069PrepareShipmentSendSp`.
3. Use **Resync Parameters**.
4. Save the IDO.
5. Verify sequence 1 `DN_No` is String / VARIANT compatible and no longer Int64 metadata.

The C# Revision 3 transport already uses `string DN_No`; no C# change should be made for this specific error.

## Retry state after the failed UAT

`P96330` and `P96331` were recorded as failed attempt 1 and moved to WAITING_BACKOFF. After correcting the signature, either wait until `NextAttemptDate` or reset each DN with `SMK069ResetShipmentRetrySp` before the next controlled UAT.

Recommended next UAT: set `Max / Run = 1`, save settings, and test only one DN.

## Why Run Now does not immediately show the final result

`Run Background Task` is asynchronous. The form submits TaskMan and returns before the server-side task necessarily completes. Refreshing immediately after submit can therefore reload the old state.

A correct automatic refresh requires polling/waiting for task completion, not a simple immediate Collection Refresh. Until that behavior is implemented in the form, use the dashboard Refresh button after the background task completes.
