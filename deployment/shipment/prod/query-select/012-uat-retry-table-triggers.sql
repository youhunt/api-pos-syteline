/* UAT Query Select - capture retry-table Mongoose triggers
   Pure SELECT only. No trailing semicolon.
*/
SELECT TOP (20)
    t.name AS TriggerName,
    t.is_instead_of_trigger,
    t.is_disabled
FROM sys.triggers AS t
WHERE t.parent_id = OBJECT_ID(N'dbo.ue_SMK069_shipment_retry_mst')
  AND t.is_ms_shipped = 0
ORDER BY t.name
