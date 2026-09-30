/* SMK Query Select Execution - PROD post-deploy config verification
   Run after 080-prod-config-template.sql.
   Exact current TRN baseline does NOT require Patch 19 Run Once bypass.
   Pure SELECT only. No trailing semicolon.
*/
SELECT
    c.SiteRef,
    c.EndpointUrl,
    c.LoginUrl,

    CASE
        WHEN c.EndpointUrl = N'https://api-prod.pizzahut.co.id/inventory-phi/v1/infor_dn'
         AND c.LoginUrl = N'https://api-prod.pizzahut.co.id/service-auth/login-once'
        THEN N'PASS' ELSE N'FAIL'
    END AS ProdUrls,

    CASE WHEN ISNULL(c.IsActive,0)=1 THEN N'PASS' ELSE N'FAIL' END AS ApiActive,

    CASE
        WHEN c.HttpMethod = N'POST'
         AND c.ContentType = N'application/json'
         AND c.AuthType = N'BEARER_LOGIN'
         AND c.AuthHeader = N'Authorization'
         AND NULLIF(c.AuthValue,N'') IS NULL
         AND c.SuccessMode = N'KACS_V1'
         AND c.TimeoutSeconds = 60
        THEN N'PASS' ELSE N'FAIL'
    END AS HttpContract,

    CASE
        WHEN (SELECT max_length
              FROM sys.columns
              WHERE object_id = OBJECT_ID(N'dbo.ue_SMK069_shipment_api_config_mst')
                AND name = N'EndpointUrl') = 2000
         AND (SELECT max_length
              FROM sys.columns
              WHERE object_id = OBJECT_ID(N'dbo.ue_SMK069_shipment_api_config_mst')
                AND name = N'LoginUrl') = 2000
         AND (SELECT max_length
              FROM sys.columns
              WHERE object_id = OBJECT_ID(N'dbo.ue_SMK069_shipment_api_config_mst')
                AND name = N'AuthValue') = 4000
        THEN N'PASS' ELSE N'FAIL'
    END AS ConfigWidths,

    CASE WHEN ISNULL(c.SchedulerEnabled,0)=0 THEN N'PASS' ELSE N'FAIL' END AS MasterOff,

    CASE WHEN ISNULL(c.MaxAttempts,0)=1440
              AND ISNULL(c.BackoffBaseMinutes,0)=1
              AND ISNULL(c.BackoffCapMinutes,0)=1
         THEN N'PASS' ELSE N'FAIL' END AS RetryPolicy,

    CASE WHEN s.ScheduleCode=N'HOURLY'
              AND s.ScheduleName=N'Every 1 Minute'
              AND ISNULL(s.IntervalMinutes,0)=1
         THEN N'PASS' ELSE N'FAIL' END AS Interval1Min,

    CASE WHEN ISNULL(s.MaxShipments,0)=1 THEN N'PASS' ELSE N'FAIL' END AS MaxRun1,

    CASE WHEN ISNULL(s.IsEnabled,0)=0 THEN N'PASS' ELSE N'FAIL' END AS BusinessOff,

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
