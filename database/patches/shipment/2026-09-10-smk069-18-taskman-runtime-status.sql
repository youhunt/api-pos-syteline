/* =============================================================================
   SMK069 - Shipment Patch 18
   TaskMan runtime truth view for Shipment Scheduler Control Center
   -----------------------------------------------------------------------------
   Date    : 2026-09-10
   Scope   : Shipment Outbound SyteLine -> POS API only

   PURPOSE
   -------
   The existing scheduler dashboard shows business/config flags such as
   SchedulerEnabled, IsEnabled, and RunState. Those values can drift from the
   actual Mongoose TaskMan queue. This patch adds a read-only runtime view that
   cross-checks the custom scheduler state against dbo.ActiveBGTasks, which is
   the actual queue consumed by TaskMan.

   IMPORTANT
   ---------
   * Does NOT enable or disable the scheduler.
   * Does NOT submit a Background Task.
   * Does NOT send HTTP.
   * Does NOT change Shipment retry state.
   * Does NOT modify existing scheduler/config tables.
   * Creates one read-only view only.
   * One executable Apply Database batch; NO GO.

   TaskMan states used:
       WAITING = recurring/scheduled task is registered and waiting
       READY   = queued and ready for TaskMan
       RUNNING = TaskMan is currently processing it
       absent  = no active TaskMan registration exists
   ============================================================================= */

SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.ActiveBGTasks', N'U') IS NULL
BEGIN
    RAISERROR(
        'Patch 18 dihentikan: dbo.ActiveBGTasks tidak terlihat pada tenant ini. Jangan menebak runtime TaskMan source.',
        16,
        1
    );
    RETURN;
END;

EXEC(N'
CREATE OR ALTER VIEW dbo.SMK069_ShipmentSchedulerRuntime_vw
AS
WITH ConfigRanked AS
(
    SELECT
        c.SiteRef,
        ISNULL(c.IsActive, 0) AS ApiActive,
        ISNULL(c.SchedulerEnabled, 0) AS MasterEnabled,
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
    WHERE c.ApiName = N''''SHIPMENT''''
),
ScheduleState AS
(
    SELECT
        s.SiteRef,
        MAX(CASE WHEN s.ScheduleCode = N''''HOURLY'''' THEN ISNULL(s.IsEnabled, 0) ELSE 0 END) AS ScheduleEnabled,
        MAX(CASE WHEN s.ScheduleCode = N''''HOURLY'''' AND s.RunState = N''''R'''' THEN 1 ELSE 0 END) AS BusinessRunning,
        MAX(CASE WHEN s.ScheduleCode = N''''HOURLY'''' THEN s.NextRunDate END) AS NextRunDate
    FROM dbo.ue_SMK069_shipment_schedule_mst AS s
    GROUP BY s.SiteRef
),
TaskManState AS
(
    SELECT
        COUNT(*) AS ActiveTaskCount,
        ISNULL(SUM(CASE
            WHEN UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(20), t.TaskStatusCode)))) = N''''RUNNING''''
            THEN 1 ELSE 0 END), 0) AS RunningCount,
        ISNULL(SUM(CASE
            WHEN UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(20), t.TaskStatusCode)))) = N''''READY''''
            THEN 1 ELSE 0 END), 0) AS ReadyCount,
        ISNULL(SUM(CASE
            WHEN UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(20), t.TaskStatusCode)))) = N''''WAITING''''
            THEN 1 ELSE 0 END), 0) AS WaitingCount,
        MAX(t.TaskNumber) AS LatestTaskNumber
    FROM dbo.ActiveBGTasks AS t
    WHERE LTRIM(RTRIM(CONVERT(NVARCHAR(128), t.TaskName))) = N''''SMK069ShipmentScheduler''''
)
SELECT
    c.SiteRef,
    CAST(N''''SMK069ShipmentScheduler'''' AS NVARCHAR(128)) AS TaskName,
    c.ApiActive,
    c.MasterEnabled,
    ISNULL(s.ScheduleEnabled, 0) AS ScheduleEnabled,
    ISNULL(s.BusinessRunning, 0) AS BusinessRunning,
    s.NextRunDate,
    t.ActiveTaskCount,
    t.RunningCount,
    t.ReadyCount,
    t.WaitingCount,
    t.LatestTaskNumber,
    CAST(CASE
        WHEN c.ApiActive = 1 THEN N''''ACTIVE''''
        ELSE N''''INACTIVE''''
    END AS NVARCHAR(30)) AS ApiStatusText,
    CAST(CASE
        WHEN c.MasterEnabled = 1 THEN N''''ON''''
        ELSE N''''OFF''''
    END AS NVARCHAR(30)) AS MasterStatusText,
    CAST(CASE
        WHEN ISNULL(s.ScheduleEnabled, 0) = 1 THEN N''''ENABLED''''
        ELSE N''''DISABLED''''
    END AS NVARCHAR(30)) AS ScheduleStatusText,
    CAST(CASE
        WHEN t.ActiveTaskCount = 0 THEN N''''NOT REGISTERED''''
        WHEN t.ActiveTaskCount > 1 THEN N''''DUPLICATE TASKS''''
        WHEN t.RunningCount > 0 THEN N''''RUNNING''''
        WHEN t.ReadyCount > 0 THEN N''''READY''''
        WHEN t.WaitingCount > 0 THEN N''''WAITING''''
        ELSE N''''PRESENT / UNKNOWN''''
    END AS NVARCHAR(40)) AS TaskManStatusText,
    CAST(CASE
        WHEN c.ApiActive <> 1 THEN N''''STOPPED - API INACTIVE''''
        WHEN c.MasterEnabled <> 1 THEN N''''STOPPED - MASTER OFF''''
        WHEN ISNULL(s.ScheduleEnabled, 0) <> 1 THEN N''''STOPPED - SCHEDULE OFF''''
        WHEN t.ActiveTaskCount = 0 THEN N''''MISCONFIGURED - TASKMAN NOT REGISTERED''''
        WHEN t.ActiveTaskCount > 1 THEN N''''WARNING - DUPLICATE TASKMAN''''
        WHEN t.RunningCount > 0 THEN N''''RUNNING NOW''''
        WHEN t.ReadyCount > 0 THEN N''''ACTIVE - READY''''
        WHEN t.WaitingCount > 0 THEN N''''ACTIVE - WAITING''''
        ELSE N''''ACTIVE - UNKNOWN TASKMAN STATE''''
    END AS NVARCHAR(80)) AS OverallStatusText,
    CAST(CASE
        WHEN ISNULL(s.BusinessRunning, 0) = 1 AND t.RunningCount = 0
            THEN N''''DRIFT - BUSINESS SAYS RUNNING, TASKMAN DOES NOT''''
        WHEN ISNULL(s.BusinessRunning, 0) = 0 AND t.RunningCount > 0
            THEN N''''DRIFT - TASKMAN RUNNING, BUSINESS SAYS IDLE''''
        ELSE N''''SYNC''''
    END AS NVARCHAR(80)) AS StateSyncText
FROM ConfigRanked AS c
LEFT JOIN ScheduleState AS s
    ON s.SiteRef = c.SiteRef
CROSS JOIN TaskManState AS t
WHERE c.rn = 1
');

PRINT 'OK - Patch 18 applied.';
PRINT 'Created dbo.SMK069_ShipmentSchedulerRuntime_vw.';
PRINT 'Runtime status now cross-checks custom scheduler flags against dbo.ActiveBGTasks.';
PRINT 'Patch ini TIDAK mengaktifkan scheduler, TIDAK submit TaskMan, dan TIDAK mengirim HTTP.';
PRINT 'NEXT: create/read-only IDO ue_SMK069ShipmentSchedulerRuntime from this view, then bind form status fields.';
