# 47 — Treat POS `data is exist` as idempotent success

Date: 2026-09-11

## Tenant evidence

During recurring Shipment retry, POS returned:

```text
HTTP 400
{"code":1010,"message":"data is exist","data":null}
```

The DN was already present on the POS side. Re-sending the same DN every minute would not improve the outcome and would only consume retry attempts / traffic.

## Required behavior

For the **Shipment POST stage only** (`SuccessMode=KACS_V1`):

```text
HTTP 201 + code 200 + message Success
    => SUCCESS

HTTP 400 + code 1010 + message "data is exist"
    => IDEMPOTENT SUCCESS / ALREADY EXISTS

other responses
    => keep existing failure handling
```

The `data is exist` response must still be preserved in the API response/history with its original HTTP 400 for audit, but operational state must become successful:

```text
BusinessSuccess = 1
Complete Shipment called with IsSuccess = 1
shipment_mst.SMK069_Uf_api_post = 1
retry RetryState = S
NextAttemptDate = NULL
LastError = NULL
no further automatic retry
```

## Important scope protection

Do **not** classify every `code=1010` as success.

The POS login endpoint has also returned code `1010` for invalid username/password. Therefore the special rule is intentionally constrained to:

```text
Shipment business response
AND SuccessMode = KACS_V1
AND HTTP = 400
AND code = 1010
AND message = "data is exist"
```

Login failures remain failures and do not consume per-DN Shipment attempts.

## Source patch

Apply the small tenant-preserving source diff:

```text
extension-classes/shipment/SMK069ShipmentDuplicateAlreadyExists.patch
```

It makes two localized changes only:

1. HTTP error responses with a response body are passed through `EvaluateBusinessResult` instead of being unconditionally marked failed.
2. `EvaluateBusinessResult` recognizes the exact duplicate response as idempotent success before the normal non-2xx failure branch.

No SQL schema change is required.

## UAT

Use a DN known to already exist at POS.

Expected after one run:

```text
HTTP                 400
Response message     data is exist
RetryState           S
Next Retry           blank
Last Error           blank
Shipment api_post    1
```

API history should keep the original HTTP 400 response so the reason for the terminal success remains auditable.

A normal HTTP 400 with a different message must remain failed/pending retry under the currently agreed retry policy.
