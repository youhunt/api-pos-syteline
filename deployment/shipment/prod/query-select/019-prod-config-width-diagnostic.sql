/* PROD config physical-width diagnostic
   Pure SELECT only. No trailing semicolon.
*/
SELECT
    (SELECT max_length
     FROM sys.columns
     WHERE object_id = OBJECT_ID(N'dbo.ue_SMK069_shipment_api_config_mst')
       AND name = N'EndpointUrl') AS EndpointUrlBytes,
    (SELECT max_length
     FROM sys.columns
     WHERE object_id = OBJECT_ID(N'dbo.ue_SMK069_shipment_api_config_mst')
       AND name = N'LoginUrl') AS LoginUrlBytes,
    (SELECT max_length
     FROM sys.columns
     WHERE object_id = OBJECT_ID(N'dbo.ue_SMK069_shipment_api_config_mst')
       AND name = N'AuthValue') AS AuthValueBytes
