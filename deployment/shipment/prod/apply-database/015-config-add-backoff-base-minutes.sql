/* PROD migration split artifact
   Source: database/patches/shipment/2026-09-08-smk069-07-shipment-scheduler-tables.sql
   Source batch: 6
   Generated to satisfy SyteLine Cloud Apply Database one-batch/no-GO execution.
   Do not add GO.
*/
IF COL_LENGTH('dbo.ue_SMK069_shipment_api_config_mst', 'BackoffBaseMinutes') IS NULL
    ALTER TABLE dbo.ue_SMK069_shipment_api_config_mst
        ADD BackoffBaseMinutes INT NULL;
