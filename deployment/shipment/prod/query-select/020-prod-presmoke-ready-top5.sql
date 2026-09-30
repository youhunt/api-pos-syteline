/* PROD pre-smoke queue verification
   Pure SELECT only. TOP + ORDER BY is intentional.
*/
SELECT TOP (5)
    q.SiteRef,
    q.ShipmentId,
    q.AttemptCount,
    q.MaxAttempts,
    q.RetryState,
    q.QueueStatus,
    q.LastAttemptDate,
    q.NextAttemptDate,
    q.LastHttpCode,
    q.LastError
FROM dbo.SMK069_ShipmentSchedulerQueue_vw AS q
WHERE q.SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND q.QueueStatus = N'READY'
ORDER BY q.AttemptCount, q.NextAttemptDate, q.ShipmentId
