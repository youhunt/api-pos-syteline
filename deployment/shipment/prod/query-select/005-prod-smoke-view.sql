/* Replace __PROD_DN__ with the controlled PROD DN.
   SMK Query Select Execution: pure SELECT, no trailing semicolon.
*/
SELECT TOP (50)
    site_ref,
    DN_No,
    Api_post,
    product_code,
    shipment_qty,
    UOM,
    Price,
    Batch,
    Expiry_date
FROM dbo.SMK069_ShipmentAPI_mst
WHERE site_ref = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND DN_No = N'__PROD_DN__'
ORDER BY product_code, Batch