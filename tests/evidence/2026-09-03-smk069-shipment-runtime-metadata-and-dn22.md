# SMK069 Shipment Runtime Metadata + DN22 Evidence — 2026-09-03

> Source: SyteLine tenant Query Execution  
> Purpose: freeze the confirmed Shipment stored-procedure contract and DN22
> lot-level UAT state before server-side sender wiring.

## 1. Stored procedure parameter metadata

| procedure_name | parameter_id | parameter_name | data_type | max_length | precision | scale | is_output |
|---|---:|---|---|---:|---:|---:|---:|
| SMK069BuildShipmentJsonSp | 1 | @DN_No | bigint | 8 | 19 | 0 | 0 |
| SMK069BuildShipmentJsonSp | 2 | @PayloadJson | nvarchar | -1 | 0 | 0 | 1 |
| SMK069BuildShipmentJsonSp | 3 | @Success | int | 4 | 10 | 0 | 1 |
| SMK069BuildShipmentJsonSp | 4 | @Infobar | nvarchar | 8000 | 0 | 0 | 1 |
| SMK069CompleteShipmentSendSp | 1 | @LogRowPointer | uniqueidentifier | 16 | 0 | 0 | 0 |
| SMK069CompleteShipmentSendSp | 2 | @HttpCode | int | 4 | 10 | 0 | 0 |
| SMK069CompleteShipmentSendSp | 3 | @ResponseJson | nvarchar | -1 | 0 | 0 | 0 |
| SMK069CompleteShipmentSendSp | 4 | @IsSuccess | int | 4 | 10 | 0 | 0 |
| SMK069CompleteShipmentSendSp | 5 | @Success | int | 4 | 10 | 0 | 1 |
| SMK069CompleteShipmentSendSp | 6 | @Infobar | nvarchar | 8000 | 0 | 0 | 1 |
| SMK069PrepareShipmentSendSp | 1 | @DN_No | bigint | 8 | 19 | 0 | 0 |
| SMK069PrepareShipmentSendSp | 2 | @EndpointUrl | nvarchar | 2000 | 0 | 0 | 0 |
| SMK069PrepareShipmentSendSp | 3 | @LogRowPointer | uniqueidentifier | 16 | 0 | 0 | 1 |
| SMK069PrepareShipmentSendSp | 4 | @PayloadJson | nvarchar | -1 | 0 | 0 | 1 |
| SMK069PrepareShipmentSendSp | 5 | @Success | int | 4 | 10 | 0 | 1 |
| SMK069PrepareShipmentSendSp | 6 | @Infobar | nvarchar | 8000 | 0 | 0 | 1 |

Interpretation for C# parameter sizing:

```text
@EndpointUrl nvarchar(1000)
@Infobar     nvarchar(4000)
Payload/Response nvarchar(max)
```

## 2. Shipment view SiteRef check

Tenant result:

```text
ShipmentViewSiteRefCheck
PASS
```

Therefore the production sender may continue relying on the active-Site
contract already implemented by the Shipment stored procedures.

## 3. DN22 current lot-level rows

Tenant result:

| site_ref | DN_No | doc_no | product_code | shipment_qty | UOM | Price | Batch | Expiry_date | Api_post |
|---|---:|---|---|---:|---|---:|---|---|---:|
| Default | 22 | CG26080002 | AA00024 | 12.00000000 | CTN | 5000.00000000 | 260812-002-1B-0 | NULL/blank | 0 |
| Default | 22 | CG26080002 | AA00024 | 3.00000000 | CTN | 5000.00000000 | 260813-008-2A-0 | NULL/blank | 0 |
| Default | 22 | CG26080002 | AA00024 | 9.00000000 | CTN | 5000.00000000 | 260814-015-1C-0 | NULL/blank | 0 |
| Default | 22 | CG26080002 | AA00024 | 6.00000000 | CTN | 5000.00000000 | 260812-003-1B-0 | NULL/blank | 0 |

Confirmed:

- Site = `Default`;
- DN22 remains pending (`Api_post=0`);
- one DOC_NO = `CG26080002`;
- four lot/batch rows remain separate;
- total shipped quantity = 30;
- no lot aggregation may be introduced by the sender.

## 4. Development consequence

The server-side one-Shipment method can use the stable lifecycle exactly as:

```text
SMK069PrepareShipmentSendSp
  -> @LogRowPointer
  -> @PayloadJson

HTTP POST

SMK069CompleteShipmentSendSp
  <- @LogRowPointer
  <- @HttpCode
  <- @ResponseJson
  <- @IsSuccess
```

There is no reason to call `SMK069BuildShipmentJsonSp` separately in the
orchestrator because Prepare already delegates JSON build/validation.
