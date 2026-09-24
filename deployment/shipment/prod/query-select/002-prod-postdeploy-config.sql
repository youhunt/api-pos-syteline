/* SMK Query Select Execution - PROD post-deploy config verification
   Run only after database objects + 080-prod-config-template.sql are applied.
   Pure SELECT only. No trailing semicolon.
*/
SELECT
    c.SiteRef,
    c.EndpointUrl,
    c.LoginUrl,
    CASE
        WHEN NULLIF(LTRIM(RTRIM(c.EndpointUrl)),N'') IS NOT NULL
         AND NULLIF(LTRIM(RTRIM(c.LoginUrl)),N'') IS NOT NULL
         AND c.EndpointUrl NOT LIKE N'%api-uat%'
         AND c.LoginUrl NOT LIKE N'%api-uat%'
        THEN N'PASS' ELSE N'FAIL'
    END AS ProdUrls,
    CASE WHEN ISNULL(c.IsActive,0)=1 THEN N'PASS' ELSE N'FAIL' END AS ApiActive,
    CASE WHEN ISNULL(c.SchedulerEnabled,0)=0 THEN N'PASS' ELSE N'FAIL' END AS MasterOff,
    CASE WHEN ISNULL(c.MaxAttempts,0)=1440
              AND ISNULL(c.BackoffBaseMinutes,0)=1
              AND ISNULL(c.BackoffCapMinutes,0)=1
         THEN N'PASS' ELSE N'FAIL' END AS RetryPolicy,
    CASE WHEN s.ScheduleCode=N'HOURLY'
              AND ISNULL(s.IntervalMinutes,0)=1
         THEN N'PASS' ELSE N'FAIL' END AS Interval1Min,
    CASE WHEN ISNULL(s.MaxShipments,0)=1 THEN N'PASS' ELSE N'FAIL' END AS MaxRun1,
    CASE WHEN ISNULL(s.IsEnabled,0)=0 THEN N'PASS' ELSE N'FAIL' END AS BusinessOff,
    CASE WHEN CHARINDEX(N'SMK069-RUNONCE-BYPASS-MASTER-R1',
              ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069RequestShipmentRunNowSp',N'P')),N'')) > 0
         THEN N'PASS' ELSE N'FAIL' END AS RunOnceBypass,
    CASE WHEN CHARINDEX(N'SMK069-PRICE-POSITIVE-R1',
              ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069BuildShipmentJsonSp',N'P')),N'')) > 0
         THEN N'PASS' ELSE N'FAIL' END AS PriceRule
FROM dbo.ue_SMK069_shipment_api_config_mst AS c
JOIN dbo.ue_SMK069_shipment_schedule_mst AS s
  ON s.SiteRef = c.SiteRef
 AND s.ScheduleCode = N'HOURLY'
WHERE c.SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND c.ApiName = N'SHIPMENT'
  AND c.IsActive = 1
