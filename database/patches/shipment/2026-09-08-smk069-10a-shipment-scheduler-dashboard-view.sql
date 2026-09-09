/* =============================================================================
   SMK069 - Shipment Scheduler Dashboard View
   Date    : 2026-09-08
   Purpose : Query Select / form-friendly read model for environments where
             DECLARE + EXEC + SELECT batches cannot be executed interactively.

   IMPORTANT FOR SYTELINE CLOUD
   ----------------------------
   Apply this file as ONE Apply Database execution. It contains exactly one
   CREATE OR ALTER VIEW statement and no GO separator.

   After creation, use SMK Query Select / Query Select against:
       dbo.SMK069_ShipmentSchedulerDashboard_vw
   ============================================================================= */
CREATE OR ALTER VIEW dbo.SMK069_ShipmentSchedulerDashboard_vw
AS
WITH ConfigRanked AS
(
    SELECT
        c.SiteRef,
        c.IsActive,
        c.SchedulerEnabled,
        c.MaxBatchSize,
        c.MaxAttempts,
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
    SELECT
        SiteRef,
        ISNULL(IsActive, 0) AS ApiActive,
        ISNULL(SchedulerEnabled, 0) AS MasterEnabled,
        COALESCE(NULLIF(MaxBatchSize, 0), 50) AS DefaultMaxBatchSize,
        COALESCE(NULLIF(MaxAttempts, 0), 5) AS MaxAttempts
    FROM ConfigRanked
    WHERE rn = 1
),
ScheduleAgg AS
(
    SELECT
        s.SiteRef,
        COUNT(*) AS ScheduleCount,
        SUM(CASE WHEN s.IsEnabled = 1 THEN 1 ELSE 0 END) AS ActiveScheduleCount,
        MIN(CASE WHEN s.IsEnabled = 1 THEN s.NextRunDate END) AS NextRunDate
    FROM dbo.ue_SMK069_shipment_schedule_mst AS s
    GROUP BY s.SiteRef
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
),
QueueAgg AS
(
    SELECT
        x.SiteRef,
        SUM(CASE
                WHEN x.RetryState = N'P'
                 AND x.AttemptCount < x.MaxAttempts
                 AND (x.NextAttemptDate IS NULL OR x.NextAttemptDate <= GETDATE())
                THEN 1 ELSE 0 END) AS ReadyCount,
        SUM(CASE
                WHEN x.RetryState = N'P'
                 AND x.AttemptCount < x.MaxAttempts
                 AND x.NextAttemptDate > GETDATE()
                THEN 1 ELSE 0 END) AS WaitingBackoffCount,
        SUM(CASE
                WHEN x.RetryState = N'X'
                  OR x.AttemptCount >= x.MaxAttempts
                THEN 1 ELSE 0 END) AS ExhaustedCount
    FROM
    (
        SELECT
            c.SiteRef,
            c.ShipmentId,
            ISNULL(r.AttemptCount, 0) AS AttemptCount,
            ISNULL(r.RetryState, N'P') AS RetryState,
            r.NextAttemptDate,
            cfg.MaxAttempts
        FROM Candidate AS c
        INNER JOIN Config AS cfg
            ON cfg.SiteRef = c.SiteRef
        LEFT JOIN dbo.ue_SMK069_shipment_retry_mst AS r
            ON r.SiteRef = c.SiteRef
           AND r.ShipmentId = c.ShipmentId
    ) AS x
    GROUP BY x.SiteRef
),
RetryToday AS
(
    SELECT
        r.SiteRef,
        SUM(CASE
                WHEN r.RetryState = N'S'
                 AND r.LastAttemptDate >= CONVERT(DATE, GETDATE())
                THEN 1 ELSE 0 END) AS SucceededToday,
        SUM(CASE
                WHEN r.RetryState IN (N'P', N'X')
                 AND r.LastAttemptDate >= CONVERT(DATE, GETDATE())
                 AND NULLIF(r.LastError, N'') IS NOT NULL
                THEN 1 ELSE 0 END) AS FailedToday
    FROM dbo.ue_SMK069_shipment_retry_mst AS r
    GROUP BY r.SiteRef
)
SELECT
    cfg.SiteRef,
    cfg.MasterEnabled,
    cfg.ApiActive,
    ISNULL(sa.ScheduleCount, 0) AS ScheduleCount,
    ISNULL(sa.ActiveScheduleCount, 0) AS ActiveScheduleCount,
    sa.NextRunDate,
    cfg.DefaultMaxBatchSize,
    cfg.MaxAttempts,
    ISNULL(qa.ReadyCount, 0) AS ReadyCount,
    ISNULL(qa.WaitingBackoffCount, 0) AS WaitingBackoffCount,
    ISNULL(qa.ExhaustedCount, 0) AS ExhaustedCount,
    ISNULL(rt.SucceededToday, 0) AS SucceededToday,
    ISNULL(rt.FailedToday, 0) AS FailedToday
FROM Config AS cfg
LEFT JOIN ScheduleAgg AS sa
    ON sa.SiteRef = cfg.SiteRef
LEFT JOIN QueueAgg AS qa
    ON qa.SiteRef = cfg.SiteRef
LEFT JOIN RetryToday AS rt
    ON rt.SiteRef = cfg.SiteRef;
