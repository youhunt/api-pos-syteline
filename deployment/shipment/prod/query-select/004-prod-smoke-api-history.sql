/* Replace __PROD_DN__ with the controlled PROD DN.
   SMK Query Select Execution: pure SELECT, no trailing semicolon.
*/
SELECT TOP (10)
    ResponseDate,
    SiteRef,
    ShipmentId,
    ProcessStatus,
    ResponseHttpCode,
    RetryCount,
    ErrorMessage,
    LEFT(ResponseJson, 200) AS ResponsePreview
FROM dbo.ue_SMK069_shipment_api_log_mst
WHERE SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND ShipmentId = N'__PROD_DN__'
ORDER BY ResponseDate DESC