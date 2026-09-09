# 05 — API Contract Draft

> Dokumen ini masih **draft**. Nama endpoint, authentication, format tanggal, batas ukuran, dan payload final harus disesuaikan dengan spesifikasi resmi tim POS dan kemampuan REST/IDO pada environment SyteLine.

## Tujuan Endpoint

Menerima satu batch yang dapat berisi transaksi untuk satu hari, satu minggu, atau rentang periode lain.

## Candidate Operation

```text
Custom IDO        : SMKRSCPosBatches
Custom IDO Method : ReceivePOSBatch
Transport         : SyteLine REST / Invoke Method
```

Endpoint aktual mengikuti konfigurasi REST SyteLine dan tidak dikunci pada path custom sebelum REST contract disepakati.

## Authentication — Open Decision

Kandidat:

- SyteLine REST authentication/session;
- service account;
- OAuth/token melalui gateway;
- API gateway + IP whitelist;
- VPN/private network.

Credential tidak boleh disimpan dalam repository.

## Request Headers — Draft

```http
Content-Type: application/json
Accept: application/json
X-Correlation-Id: <optional-client-correlation-id>
Idempotency-Key: <optional-unique-request-key>
```

## Draft Payload

```json
{
  "externalBatchNum": "PH-SBY-001-20260723-001",
  "requestId": "REQ-POS-20260723-000001",
  "sourceSystem": "PIZZAHUT_POS",
  "outletCode": "PH-SBY-001",
  "periodStart": "2026-07-23",
  "periodEnd": "2026-07-23",
  "sentAt": "2026-07-24T01:15:30+07:00",
  "summary": {
    "transactionCount": 1,
    "grossAmount": 200000,
    "discountAmount": 20000,
    "taxAmount": 18000,
    "serviceAmount": 0,
    "roundingAmount": 0,
    "netAmount": 198000,
    "paymentAmount": 198000
  },
  "transactions": [
    {
      "transactionNum": "TRX-PH001-000001",
      "receiptNum": "RCP-000001",
      "businessDate": "2026-07-23",
      "transactionDateTime": "2026-07-23T12:35:20+07:00",
      "transactionType": "SALE",
      "originalTransactionNum": null,
      "cashierCode": "CSR001",
      "orderType": "TAKEAWAY",
      "salesChannel": "POS",
      "currencyCode": "IDR",
      "grossAmount": 200000,
      "discountAmount": 20000,
      "taxAmount": 18000,
      "serviceAmount": 0,
      "roundingAmount": 0,
      "netAmount": 198000,
      "paymentAmount": 198000,
      "items": [
        {
          "lineNum": 1,
          "parentLineNum": null,
          "itemCode": "PIZZA001",
          "description": "Super Supreme Large",
          "lineType": "ITEM",
          "qty": 1,
          "uom": "PCS",
          "unitPrice": 200000,
          "grossAmount": 200000,
          "discountAmount": 20000,
          "taxAmount": 18000,
          "serviceAmount": 0,
          "netAmount": 198000,
          "taxCode": "PB1",
          "promoCode": "PROMO-JULY",
          "void": false
        }
      ],
      "payments": [
        {
          "sequence": 1,
          "paymentCode": "QRIS_BCA",
          "description": "QRIS BCA",
          "paymentType": "QRIS",
          "currencyCode": "IDR",
          "amount": 198000,
          "feeAmount": 0,
          "netSettlementAmount": 198000,
          "referenceNum": "QRIS-20260723-00001",
          "settlementDate": null
        }
      ]
    }
  ]
}
```

## Mapping ke Staging

| Payload | Staging Column |
|---|---|
| `externalBatchNum` | Batch.`ext_batch_num` |
| `requestId` | Batch.`request_id` |
| `sourceSystem` | Batch.`source_system` |
| `outletCode` | Batch/Tran.`outlet_code` |
| `periodStart` | Batch.`period_start` |
| `periodEnd` | Batch.`period_end` |
| `transactionNum` | Tran.`trans_num` |
| `itemCode` | TranLine.`pos_item_code` |
| `sequence` | Payment.`payment_seq` |
| `paymentCode` | Payment.`payment_code` |

## Response: Accepted

```json
{
  "success": true,
  "code": "BATCH_RECEIVED",
  "message": "POS batch was received and stored in SyteLine staging.",
  "data": {
    "batchNum": "SMKPOS-20260723-000001",
    "externalBatchNum": "PH-SBY-001-20260723-001",
    "requestId": "REQ-POS-20260723-000001",
    "correlationId": "CORR-7F20A618",
    "status": "R",
    "transactionCount": 1,
    "receivedAt": "2026-07-24T01:15:32+07:00"
  }
}
```

Respons ini hanya berarti data masuk staging. Respons tidak berarti jurnal/AR/inventory sudah diposting.

## Response: Duplicate

Idempotent duplicate dapat dikembalikan sebagai respons berhasil dengan status record existing, atau conflict sesuai keputusan contract.

```json
{
  "success": true,
  "code": "BATCH_ALREADY_RECEIVED",
  "message": "The same batch has already been received.",
  "data": {
    "batchNum": "SMKPOS-20260723-000001",
    "status": "P"
  }
}
```

## Response: Structural Validation Error

```json
{
  "success": false,
  "code": "INVALID_PAYLOAD",
  "message": "The request structure is invalid.",
  "errors": [
    {
      "field": "transactions[0].items[0].qty",
      "code": "REQUIRED",
      "message": "Quantity is required."
    }
  ]
}
```

## Proposed Status Query

Bila diperlukan, POS dapat mengecek status berdasarkan external batch/request:

```text
Get batch status by ext_batch_num / request_id
```

Draft response:

```json
{
  "success": true,
  "data": {
    "batchNum": "SMKPOS-20260723-000001",
    "status": "E",
    "transactionCount": 1000,
    "validatedCount": 995,
    "errorCount": 5,
    "lastError": "Five item codes are not mapped."
  }
}
```

## Required API Rules

- Reject malformed JSON.
- Validate maximum collection size.
- Validate required fields before insert.
- Enforce idempotency.
- Never trust totals without server-side recalculation.
- Never accept target GL account from an untrusted POS payload.
- Do not store full card number, CVV, PIN, or track data.
- Sanitize error response; technical details remain in internal process log.
- Return `correlation_id` for support tracing.

## Open Contract Questions

1. Apakah POS push data langsung atau melalui middleware?
2. Apakah payload satu batch atau per transaksi?
3. Apakah item modifier/package dikirim sebagai child line?
4. Apakah void/refund dikirim sebagai negative values atau transaction type?
5. Apakah payment settlement dikirim bersamaan atau terpisah?
6. Apakah request dapat berisi beberapa outlet?
7. Berapa volume maksimal transaksi dan line per request?
8. Apakah source menyediakan external batch number yang stabil?
9. Timezone dan business-date cutoff yang digunakan?
10. Apakah response synchronous atau asynchronous acknowledgment?
