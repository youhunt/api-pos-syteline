# Implementation 06 — Add `CreateManualInbound` Method

## Scope

Menambahkan method pertama pada service IDO:

```text
IDO    : ue_SMKRSCPosIntegration
Method : CreateManualInbound
Type   : Stored Procedure, no result set
SP     : dbo.ue_SMKRSCPosCreateManualInboundSp
```

Method ini hanya membuat satu record inbound untuk memulai proses upload CSV manual. Method belum membaca file, belum membuat batch, dan belum membuat raw lines.

## Stored Procedure Parameters

Urutan parameter harus sama dengan deklarasi stored procedure:

| Sequence | Parameter | Direction | SQL Type |
|---:|---|---|---|
| 1 | `SourceSystem` | Input | nvarchar(30) |
| 2 | `OutletCode` | Input | nvarchar(20) |
| 3 | `SourceReference` | Input | nvarchar(100) |
| 4 | `PayloadVersion` | Input | nvarchar(20) |
| 5 | `InboundId` | Output | uniqueidentifier |
| 6 | `RequestId` | Output | nvarchar(50) |
| 7 | `Infobar` | Output | nvarchar(1000) |

## Stored Procedure Behavior

On success:

```text
Return value : 0
Stat         : R
PayloadFormat: C
StorageMode  : N
ContentType  : text/csv
EndpointName : MANUAL_CSV
HttpMethod   : UPLOAD
```

`StorageMode = N` digunakan saat record baru dibuat karena file belum di-attach. Method berikutnya akan mengubah storage metadata setelah attachment tersedia.

On validation or database error:

```text
Return value : 16
InboundId    : NULL
RequestId    : NULL
Infobar      : error detail
```

## Add Method Through IDO Method Wizard

1. Open `IDOs`.
2. Find `ue_SMKRSCPosIntegration`.
3. Check Out the IDO.
4. Click `New Method`.
5. Fill the wizard:

```text
Method Type      : Stored Procedure — no result set
Stored Procedure : ue_SMKRSCPosCreateManualInboundSp
Method Name      : CreateManualInbound
Transactional    : checked
```

6. Click `OK`.
7. Refresh the IDOs form.
8. Open the Methods tab.
9. Verify the parameter order and directions.
10. Save and Check In the IDO.
11. Discard IDO Cache.
12. Re-login only if the web client still uses stale method metadata.

## Why Transactional

The method inserts one inbound record and must either commit fully or roll back. Mongoose transactional IDO methods commit when the stored procedure returns a value below 5 and roll back for a return value of 5 or higher. The project uses `0` for success and `16` for failure.

## Expected Result

Example input:

```text
SourceSystem    : PIZZAHUT_POS
OutletCode      : PH-SBY-001
SourceReference : pos_20260723.csv
PayloadVersion  : POS_MINIMAL_V1
```

Example output:

```text
InboundId : generated GUID
RequestId : MAN-20260723-HHMMSS-XXXXXXXX
Infobar   : Manual inbound berhasil dibuat. Request ID: ...
Return    : 0
```

The new record must be visible through:

```text
ue_SMKRSCPosInbounds
```

with initial values:

```text
Stat            = R
PayloadFormat   = C
StorageMode     = N
RowCount        = 0
AcceptedCount   = 0
RejectedCount   = 0
BatchNum        = NULL
```

## Stop Point

This step is complete when:

```text
[ ] Stored procedure exists in the application database
[ ] CreateManualInbound appears on the Methods tab
[ ] Transactional is checked
[ ] Parameter order and output flags are correct
[ ] IDO is checked in
[ ] Method metadata is recognized after cache refresh
```

Do not create `ValidateAttachedCsv` until this method can be invoked successfully.
