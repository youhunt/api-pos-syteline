# 32 — Shipment missing DOC_NO becomes non-blocking

> Date: 9 September 2026  
> Scope: **Shipment Outbound SyteLine → POS API only**  
> Patch: `database/patches/shipment/2026-09-09-smk069-14-allow-missing-doc-no.sql`  
> Current revision: **Revision 2**

## 1. Business request

Queue evidence showed:

```text
P96331 WAITING_BACKOFF attempt 3/5 HTTP 0
Shipment DN P96331 tidak mempunyai DOC_NO/Customer Order.
```

Requested behavior:

> A Shipment must not stop locally only because `DOC_NO` is empty.

The Shipment should still be allowed to Build/Prepare and reach the POS API.

## 2. Revision 1 tenant result

Patch 14 Rev.1 attempted an optional Shipment View fallback and deliberately
looked for this exact projection in the installed tenant View:

```text
co.co_num AS doc_no
```

Tenant Apply Database returned:

```text
Projection "co.co_num AS doc_no" tidak ditemukan pada tenant View.
Patch 14 dihentikan; jangan replace full View dari Git.
```

This is a **safe abort**, not a partial deployment. Rev.1 was inside a
transaction and rolled back. It did not replace the tenant View or Build SP.

The result also proves again that the historical standalone View source in Git
is not identical to the current tenant runtime.

## 3. Revision 2 design

The View fallback is not required for the actual business request, so Revision 2
removes that dependency entirely.

**Revision 2 does not alter `dbo.SMK069_ShipmentAPI_mst`.**

It patches only the installed current tenant definition of:

```text
dbo.SMK069BuildShipmentJsonSp
```

The patch first verifies that `@DN_No` is already a String data type so it cannot
accidentally restore the obsolete BIGINT contract for values such as `P96331`.

## 4. New Build behavior

Previously the Build procedure stopped in the missing-DOC_NO path:

```text
DocCount = 0
-> "tidak mempunyai DOC_NO/Customer Order."
-> RETURN
```

and the header validation could stop again at:

```text
@DocNo blank
-> "DOC_NO kosong."
-> RETURN
```

Revision 2 removes only those two local `RETURN` operations.

If `DOC_NO` remains NULL/blank, JSON is normalized to:

```json
"DOC_NO": ""
```

The POS API becomes the final authority on whether a blank DOC_NO is accepted.
SyteLine no longer blocks the Shipment before HTTP solely for that reason.

## 5. What remains protected

The existing multiple-document protection remains active:

```text
one Shipment -> more than one distinct nonblank DOC_NO
              -> reject before HTTP
```

Other Shipment validation remains unchanged, including:

- Shipment exists and is pending;
- shipment quantity > 0;
- CUST_CODE required;
- WHS_CODE required;
- DELIVERY_DATE required;
- STORE_ORDER_NO required;
- PRODUCT_CODE required;
- lot/batch detail preserved.

## 6. Apply Revision 2

Use Infor **Apply Database** with the current Git file:

```text
database/patches/shipment/2026-09-09-smk069-14-allow-missing-doc-no.sql
```

Expected final messages:

```text
OK - Patch 14 Revision 2 applied.
Shipment View TIDAK diubah.
Missing DOC_NO tidak lagi menghentikan Build.
Jika DOC_NO tetap kosong, JSON berisi DOC_NO="".
Multiple distinct DOC_NO protection tetap aktif.
Patch ini TIDAK melakukan retry / HTTP call.
JANGAN Run Now sebelum HTTP 404 dan Complete nvarchar->bigint dibereskan.
```

## 7. Verification — no Shipment send yet

Verify the markers through Query Select:

```sql
SELECT
    TYPE_NAME(p.user_type_id) AS DN_No_Type,
    CASE
        WHEN OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069BuildShipmentJsonSp', N'P'))
             LIKE N'%SMK069-DOC-NONBLOCKING-R2%'
            THEN N'PASS'
        ELSE N'FAIL'
    END AS DocNoNonBlocking,
    CASE
        WHEN OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069BuildShipmentJsonSp', N'P'))
             LIKE N'%ISNULL(@DocNo, N'''') AS [DOC_NO]%'
            THEN N'PASS'
        ELSE N'FAIL'
    END AS EmptyStringJson
FROM sys.parameters AS p
WHERE p.object_id = OBJECT_ID(N'dbo.SMK069BuildShipmentJsonSp', N'P')
  AND p.parameter_id = 1;
```

Expected:

```text
DN_No_Type       nvarchar/varchar
DocNoNonBlocking PASS
EmptyStringJson  PASS
```

Then inspect the P96331 View rows without sending:

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

The View may still show `doc_no = NULL/blank`; that is allowed by Revision 2.
The important change is that Build no longer returns failure only for that blank
value.

## 8. Important: do not retry yet

Patch 14 Revision 2 fixes only the **local DOC_NO gate**.

Independent shared blockers remain:

```text
P96330 / P96332
  HTTP 404 page not found

P96330 / P96332
  SMK069CompleteShipmentSendSp line 36
  nvarchar -> bigint conversion
```

Those shared sender/Complete paths will also be used once P96331 gets past
Build/Prepare.

Correct sequence:

```text
1. Apply Patch 14 Revision 2.
2. Verify PASS/PASS markers.
3. Keep scheduler/retry held.
4. Capture/fix exact tenant Complete line 36.
5. Confirm the correct POS EndpointUrl.
6. Set Max/Run = 1.
7. Reset ONE DN only.
8. Controlled UAT.
9. Verify HTTP + Complete + API log + retry + Api_post.
```

Do not reset all three DNs at once.
