# EXT-001 — Extension Assembly Build

## Object

```text
Assembly Name : ue_SMKRSCPosExtensions
Assembly Type : Build From Source
Language      : C#
Access As     : ue_
```

## Observed Result

The SyteLine/Mongoose web client shows the assembly record with a generated revision and full assembly identity. The `Check Out` button is active while `Build Assembly` is disabled, indicating the assembly has been built and is currently checked in.

```text
Assembly build : PASS
Assembly exists: PASS
Checked in     : PASS
```

## Source

```text
File      : SMKRSCPosIntegrationExtension.cs
Namespace : SMKRSCPos
Class     : SMKRSCPosIntegrationExtension
Target IDO: ue_SMKRSCPosIntegration
Method    : ue_ValidateAttachedCsv
```

## Next Step

Link `ue_SMKRSCPosExtensions` to `ue_SMKRSCPosIntegration`, then create the `Extension Class - Standard Method` metadata for `ue_ValidateAttachedCsv` and resync its eleven parameters.
