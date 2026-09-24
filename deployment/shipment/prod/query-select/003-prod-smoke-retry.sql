/* Replace __PROD_DN__ with the controlled PROD DN.
   SMK Query Select Execution: pure SELECT, no trailing semicolon.
*/
SELECT TOP (1)
    SiteRef,
    ShipmentId,
    RetryState,
    AttemptCount,
    FirstAttemptDate,
    LastAttemptDate,
    NextAttemptDate,
    LastHttpCode,
    LastError
FROM dbo.ue_SMK069_shipment_retry_mst
WHERE SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND ShipmentId = N'__PROD_DN__'
ORDER BY LastAttemptDate DESC