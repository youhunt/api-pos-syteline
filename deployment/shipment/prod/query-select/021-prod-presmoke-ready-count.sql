/* PROD pre-smoke READY count verification
   Pure SELECT only. No trailing semicolon.
*/
SELECT
    COUNT(*) AS ReadyRows
FROM dbo.SMK069_ShipmentSchedulerQueue_vw
WHERE SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND QueueStatus = N'READY'
