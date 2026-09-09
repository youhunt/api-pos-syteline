# 32 — Shipment missing DOC_NO becomes non-blocking

> Date: 9 September 2026  
> Scope: **Shipment Outbound SyteLine → POS API only**  
> Patch: `database/patches/shipment/2026-09-09-smk069-14-allow-missing-doc-no.sql`

## 1. Business request

Queue evidence showed:

```text
P96331 WAITING_BACKOFF attempt 3/5 HTTP 0
Shipment DN P96331 tidak mempunyai DOC_NO/Customer Order.
```

The requested behavior is that a Shipment must not stop locally only because
`DOC_NO` is empty.

Patch 14 implements that request without mixing the Shipment workstream with
CSV→CO processing.

## 2. New DOC_NO resolution

The Shipment view now prefers a real existing order reference in this order:

```text
1. co_mst.co_num
2. coitem_mst.co_num
3. shipment_line_mst.ref_num
4. empty if none exists
```

This is important because `shipment_line.ref_num` is already the Shipment's
source-document reference used to join to `coitem_mst`. A missing `co_mst`
header should not automatically erase that source reference from the outbound
payload.

The patch edits the installed tenant view through `OBJECT_DEFINITION`; it does
not replace the full view with the stale 4 Sep Git copy. Current prefixed DN and
numeric-UOM tenant logic are therefore preserved.

## 3. Build behavior when all DOC_NO sources are blank

Previously `SMK069BuildShipmentJsonSp` stopped in two places:

```text
DocCount = 0
-> "tidak mempunyai DOC_NO/Customer Order."
-> RETURN

@DocNo blank
-> "DOC_NO kosong."
-> RETURN
```

Patch 14 makes both guards non-blocking.

If no real reference exists, the payload is still built with:

```json
"DOC_NO": ""
```

The POS API becomes the final authority on whether blank DOC_NO is acceptable.
SyteLine no longer blocks the Shipment before the HTTP call.

## 4. What remains protected

The existing multiple-document guard remains active:

```text
one Shipment -> more than one distinct DOC_NO
              -> reject before HTTP
```

Patch 14 does **not** silently choose one of several Customer Orders.

Other required Shipment validation also remains unchanged:

- Shipment exists and is pending;
- shipment quantity > 0;
- CUST_CODE required;
- WHS_CODE required;
- DELIVERY_DATE required;
- STORE_ORDER_NO required;
- PRODUCT_CODE required;
- lot/batch detail preserved.

## 5. Apply

Infor **Apply Database**:

```text
database/patches/shipment/2026-09-09-smk069-14-allow-missing-doc-no.sql
```

Expected final messages:

```text
OK - Patch 14 applied.
DOC_NO sekarang fallback co_mst -> coitem -> shipment_line.ref_num.
Jika tetap kosong, Build tetap menghasilkan JSON dengan DOC_NO="".
Multiple DOC_NO protection tetap aktif.
JANGAN retry sebelum HTTP 404 dan Complete nvarchar->bigint diperbaiki.
```

The patch is guarded and transactional. If the tenant source differs from the
expected fragments, it rolls back instead of overwriting the object using stale
Git source.

## 6. Verification — Query Select

After Apply Database, verify P96331 without sending it:

```sql
SELECT
    DN_No,
    doc_no,
    cust_code,
    whse_code,
    Store_Order_No,
    store_code,
    product_code,
    shipment_qty,
    UOM,
    Price,
    Api_post
FROM dbo.SMK069_ShipmentAPI_mst
WHERE LTRIM(RTRIM(CONVERT(NVARCHAR(40), DN_No))) = N'P96331'
ORDER BY product_code, Batch;
```

Then verify the underlying reference chain:

```sql
SELECT
    sh.site_ref,
    sh.shipment_id,
    shl.shipment_line,
    shl.ref_num AS shipment_ref_num,
    shl.ref_line_suf,
    shl.ref_release,
    coi.co_num AS coitem_co_num,
    co.co_num AS co_header_num,
    CASE
        WHEN NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(50), co.co_num))), N'') IS NOT NULL
            THEN N'CO_HEADER'
        WHEN NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(50), coi.co_num))), N'') IS NOT NULL
            THEN N'COITEM'
        WHEN NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(50), shl.ref_num))), N'') IS NOT NULL
            THEN N'SHIPMENT_REF'
        ELSE N'BLANK'
    END AS DocNoSource
FROM dbo.shipment_mst AS sh
LEFT JOIN dbo.shipment_line_mst AS shl
  ON shl.site_ref = sh.site_ref
 AND shl.shipment_id = sh.shipment_id
LEFT JOIN dbo.coitem_mst AS coi
  ON coi.site_ref = sh.site_ref
 AND coi.co_num = shl.ref_num
 AND coi.co_line = shl.ref_line_suf
 AND coi.co_release = shl.ref_release
LEFT JOIN dbo.co_mst AS co
  ON co.site_ref = coi.site_ref
 AND co.co_num = coi.co_num
WHERE sh.site_ref = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND (
        LTRIM(RTRIM(CONVERT(NVARCHAR(40), sh.shipment_id))) = N'31'
        OR LTRIM(RTRIM(CONVERT(NVARCHAR(40), shl.ref_num))) = N'P96331'
      )
ORDER BY sh.shipment_id, shl.shipment_line;
```

The second query is diagnostic only. Depending on how the current tenant builds
the `P963xx` DN prefix, use the first view query as the authoritative P96331
check.

## 7. Important: do not retry yet

Patch 14 fixes only the **local DOC_NO gate**.

Current independent blockers remain:

```text
P96330 / P96332
  HTTP 404 page not found

P96330 / P96332
  SMK069CompleteShipmentSendSp line 36
  nvarchar -> bigint conversion
```

Those issues can affect the same sender used by P96331. Therefore do not spend
another retry yet.

The correct sequence is:

```text
1. Apply Patch 14.
2. Verify P96331 now builds / exposes DOC_NO fallback or blank.
3. Fix/confirm EndpointUrl.
4. Fix Complete Shipment string-DN handling from exact tenant source.
5. Set Max/Run = 1.
6. Reset ONE DN only.
7. Run controlled UAT.
8. Verify HTTP + Complete + API log + retry + Api_post.
```

## 8. Retry policy after root causes are fixed

Do not reset all three DNs together.

Recommended first candidate:

```text
P96331
```

because Patch 14 directly targets its previous local validation failure. But it
should only be used after the shared HTTP/Complete path is clean.

If the resulting payload has `DOC_NO=""` and POS rejects it, keep that response
as contract evidence. At that point we will know blank DOC_NO is rejected by POS
rather than blocked by SyteLine, and a business-approved substitute value can be
defined explicitly instead of invented in the integration.
