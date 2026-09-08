/* =============================================================================
   SMK069 - Shipment Scheduler Queue View
   Date    : 2026-09-08
   Purpose : Query Select / form-friendly per-DN queue state.

   IMPORTANT FOR SYTELINE CLOUD
   ----------------------------
   Apply this file as ONE Apply Database execution. It contains exactly one
   CREATE OR ALTER VIEW statement and no GO separator.
   ============================================================================= */
CREATE OR ALTER VIEW dbo.SMK069_ShipmentSchedulerQueue_vw
AS
WITH ConfigRanked AS
(
    SELECT
        c.SiteRef,
        COALESCE(NULLIF(c.MaxAttempts, 0), 5) AS MaxAttempts,
        c.RecordDate,
        c.RowPointer,
        ROW_NUMBER() OVER
        (
            PARTITION BY c.SiteRef
            ORDER BY ISNULL(c.IsActive, 0) DESC,
                     c.RecordDate DESC,
                     c.RowPointer DESC
        ) AS rn
    FROM dbo.ue_SMK069_shipment_api_config_mst AS c
    WHERE c.ApiName = N'SHIPMENT'
),
Config AS
(
    SELECT SiteRef, MaxAttempts
    FROM ConfigRanked
    WHERE rn = 1
),
Candidate AS
(
    SELECT DISTINCT
        v.site_ref AS SiteRef,
        LTRIM(RTRIM(CONVERT(NVARCHAR(40), v.DN_No))) AS ShipmentId
    FROM dbo.SMK069_ShipmentAPI_mst AS v
    WHERE ISNULL(v.Api_post, 0) = 0
      AND ISNULL(v.shipment_qty, 0) > 0
      AND NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(40), v.DN_No))), N'') IS NOT NULL
)
SELECT
    c.SiteRef,
    c.ShipmentId,
    ISNULL(r.AttemptCount, 0) AS AttemptCount,
    cfg.MaxAttempts,
    ISNULL(r.RetryState, N'P') AS RetryState,
    CASE
        WHEN ISNULL(r.RetryState, N'P') = N'X'
          OR ISNULL(r.AttemptCount, 0) >= cfg.MaxAttempts
            THEN N'EXHAUSTED'
        WHEN ISNULL(r.RetryState, N'P') = N'P'
         AND r.NextAttemptDate IS NOT NULL
         AND r.NextAttemptDate > GETDATE()
            THEN N'WAITING_BACKOFF'
        WHEN ISNULL(r.RetryState, N'P') = N'P'
         AND ISNULL(r.AttemptCount, 0) < cfg.MaxAttempts
         AND (r.NextAttemptDate IS NULL OR r.NextAttemptDate <= GETDATE())
            THEN N'READY'
        WHEN ISNULL(r.RetryState, N'P') = N'S'
            THEN N'INCONSISTENT_SUCCESS'
        ELSE N'OTHER'
    END AS QueueStatus,
    r.FirstAttemptDate,
    r.LastAttemptDate,
    r.NextAttemptDate,
    r.LastHttpCode,
    r.LastError
FROM Candidate AS c
INNER JOIN Config AS cfg
    ON cfg.SiteRef = c.SiteRef
LEFT JOIN dbo.ue_SMK069_shipment_retry_mst AS r
    ON r.SiteRef = c.SiteRef
   AND r.ShipmentId = c.ShipmentId;
