/*
SMK069 Shipment Production Readiness Audit
Query Execution version
Date: 2026-09-03

IMPORTANT
---------
Run EACH numbered SELECT block separately in the SyteLine/Mongoose
Query Execution form.

Do NOT use Apply Database for these checks. Apply Database executes the SQL
but does not display SELECT result grids like SSMS.

All queries are READ-ONLY.
*/


/* ============================================================
   Q1 - Active Site
   Expected: one row with the current Site.
   ============================================================ */
SELECT
    RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0)) AS ActiveSite;


/* ============================================================
   Q2 - Shipment stored procedure Site-context audit
   Expected for the three Shipment SPs:
     HasSiteContext = YES
     HasSetSiteSp   = YES
     HasSiteReference = YES
   ============================================================ */
SELECT
    p.name AS procedure_name,
    CASE
        WHEN m.definition LIKE '%CONTEXT_INFO%' THEN 'YES'
        ELSE 'NO'
    END AS HasSiteContext,
    CASE
        WHEN m.definition LIKE '%SetSiteSp%' THEN 'YES'
        ELSE 'NO'
    END AS HasSetSiteSp,
    CASE
        WHEN m.definition LIKE '%site_ref%'
          OR m.definition LIKE '%SiteRef%' THEN 'YES'
        ELSE 'NO'
    END AS HasSiteReference,
    CASE
        WHEN m.definition LIKE '%''DEFAULT''%' THEN 'CHECK'
        ELSE 'OK'
    END AS HasDefaultLiteral
FROM sys.procedures p
JOIN sys.sql_modules m
    ON m.object_id = p.object_id
WHERE p.name IN
(
    'SMK069BuildShipmentJsonSp',
    'SMK069PrepareShipmentSendSp',
    'SMK069CompleteShipmentSendSp'
)
ORDER BY p.name;


/* ============================================================
   Q3 - Exact parameter metadata for Build / Prepare / Complete
   IMPORTANT: send this result back for final orchestration wiring.
   ============================================================ */
SELECT
    o.name AS procedure_name,
    p.parameter_id,
    p.name AS parameter_name,
    TYPE_NAME(p.user_type_id) AS data_type,
    p.max_length,
    p.precision,
    p.scale,
    p.is_output
FROM sys.objects o
JOIN sys.parameters p
    ON p.object_id = o.object_id
WHERE o.type = 'P'
  AND o.name IN
  (
      'SMK069BuildShipmentJsonSp',
      'SMK069PrepareShipmentSendSp',
      'SMK069CompleteShipmentSendSp'
  )
ORDER BY
    o.name,
    p.parameter_id;


/* ============================================================
   Q4 - Shipment API view columns
   Must include site_ref.
   ============================================================ */
SELECT
    c.column_id,
    c.name AS column_name,
    TYPE_NAME(c.user_type_id) AS data_type,
    c.max_length,
    c.is_nullable
FROM sys.columns c
WHERE c.object_id = OBJECT_ID('dbo.SMK069_ShipmentAPI_mst')
ORDER BY c.column_id;


/* ============================================================
   Q5 - Simple site_ref existence check
   Expected: PASS
   ============================================================ */
SELECT
    CASE
        WHEN OBJECT_ID('dbo.SMK069_ShipmentAPI_mst', 'V') IS NULL
            THEN 'FAIL - view missing'
        WHEN COL_LENGTH('dbo.SMK069_ShipmentAPI_mst', 'site_ref') IS NULL
            THEN 'FAIL - site_ref missing'
        ELSE 'PASS'
    END AS ShipmentViewSiteRefCheck;


/* ============================================================
   Q6 - Outbound Shipment log columns
   ============================================================ */
SELECT
    c.column_id,
    c.name AS column_name,
    TYPE_NAME(c.user_type_id) AS data_type,
    c.max_length,
    c.precision,
    c.scale,
    c.is_nullable
FROM sys.columns c
WHERE c.object_id =
    OBJECT_ID('dbo.ue_SMK069_shipment_api_log_mst')
ORDER BY c.column_id;


/* ============================================================
   Q7 - Pending Shipment snapshot for current Site
   This uses the current CONTEXT_INFO Site inline, so no DECLARE
   is needed.

   DN22 should appear if it is still pending in this Site.
   ============================================================ */
SELECT
    site_ref,
    DN_No,
    MAX(Delivery_date) AS Delivery_date,
    MAX(doc_no) AS doc_no,
    COUNT(*) AS detail_rows,
    SUM(
        CASE
            WHEN ISNULL(shipment_qty, 0) > 0 THEN 1
            ELSE 0
        END
    ) AS positive_qty_rows,
    MAX(ISNULL(Api_post, 0)) AS Api_post
FROM dbo.SMK069_ShipmentAPI_mst
WHERE site_ref =
      RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND ISNULL(Api_post, 0) = 0
GROUP BY
    site_ref,
    DN_No
ORDER BY
    DN_No;


/* ============================================================
   Q8 - Current DN22 detail / lot verification
   Expected: separate rows per batch/lot; do not aggregate.
   ============================================================ */
SELECT
    site_ref,
    DN_No,
    doc_no,
    product_code,
    shipment_qty,
    UOM,
    Price,
    Batch,
    Expiry_date,
    Api_post
FROM dbo.SMK069_ShipmentAPI_mst
WHERE site_ref =
      RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND CONVERT(NVARCHAR(50), DN_No) = '22'
ORDER BY
    product_code,
    Batch;


/* ============================================================
   Q9 - Suspicious duplicate active/success log attempts
   Logical key = SiteRef + ShipmentId.

   Expected normally: no rows.
   ============================================================ */
SELECT
    SiteRef,
    ShipmentId,
    SUM(
        CASE
            WHEN ProcessStatus = 'N' THEN 1
            ELSE 0
        END
    ) AS NewCount,
    SUM(
        CASE
            WHEN ProcessStatus = 'S' THEN 1
            ELSE 0
        END
    ) AS SuccessCount,
    SUM(
        CASE
            WHEN ProcessStatus = 'E' THEN 1
            ELSE 0
        END
    ) AS ErrorCount,
    COUNT(*) AS TotalAttempts
FROM dbo.ue_SMK069_shipment_api_log_mst
WHERE SiteRef =
      RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
GROUP BY
    SiteRef,
    ShipmentId
HAVING
       SUM(CASE WHEN ProcessStatus = 'N' THEN 1 ELSE 0 END) > 1
    OR SUM(CASE WHEN ProcessStatus = 'S' THEN 1 ELSE 0 END) > 1
ORDER BY
    ShipmentId;
