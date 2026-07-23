# Implementation 05 — Create `ue_SMKRSCPosIntegration`

## Scope

Create the method-focused service IDO shell. This step only creates the IDO metadata. CSV import methods are added one by one afterward.

```text
IDO Project        : ue_SMKRSCPos
IDO Name           : ue_SMKRSCPosIntegration
Architectural Role : Service IDO
Primary Base Table : ue_SMK_RSC_POS_Batch_mst
Table Alias        : svc
Primary Key        : BatchNum
```

Using the Batch table does not mean the public integration performs direct CRUD on this IDO. The collection is only the technical base required for the IDO; processing will use IDO methods.

## Wizard

```text
Project Name       : ue_SMKRSCPos
Primary Base Table : ue_SMK_RSC_POS_Batch_mst
Table Alias        : svc
IDO Name           : ue_SMKRSCPosIntegration
Extends             : blank
```

Use the actual table name shown in the tenant dropdown and avoid a duplicated `ue_` prefix.

## Properties

Keep all generated bound properties for the first implementation. Use PascalCase names consistent with `ue_SMKRSCPosBatches`.

Important properties:

```text
BatchNum
RequestId
SourceSystem
InputType
OutletCode
PeriodStart
PeriodEnd
ReceivedDate
TransCount
NetAmt
Stat
ValidationMsg
ErrorMsg
RetryCount
RowPointer
RecordDate
SiteRef
```

## Primary Key

Advanced Attributes should contain:

```text
1. BatchNum
```

## Save and Cache Refresh

```text
Save
Check In
Discard IDO Cache
Create a new web-client session when the current session still cannot discover the IDO
```

Suggested check-in comment:

```text
Create ue_SMKRSCPosIntegration service IDO shell
```

## Smoke Test

Use IDO Data Viewer:

```text
IDO        : ue_SMKRSCPosIntegration
Properties : BatchNum, RequestId, SourceSystem, InputType, Stat, RowPointer, SiteRef
Expected   : Load Collection succeeds; zero rows is acceptable
```

## Important Restriction

Do not use this service IDO as a public direct-insert endpoint.

Future invocation flow:

```text
Manual CSV form / REST
        ↓ Invoke
ue_SMKRSCPosIntegration.<MethodName>
        ↓
Inbound + Batch + RawLine + ProcessLog
```

## Methods Added After the Shell Passes

Methods will be implemented one by one:

```text
1. CreateManualInbound
2. ValidateAttachedCsv
3. ImportAttachedCsv
4. ValidateBatch
5. RetryBatch
6. GeneratePostingPreview
```

The first method to design after the service IDO smoke test is `CreateManualInbound`.
