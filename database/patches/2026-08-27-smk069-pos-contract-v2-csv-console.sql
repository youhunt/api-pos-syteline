/*
    SMK069 POS Contract V2 - CSV Console schema alignment
    Date: 2026-08-27

    Purpose:
      - Add cust_po to CSV detail, inbound, and temp tables where missing.
      - Ensure POS field mapping for cust_po exists.
      - Keep the script idempotent for Cloud Apply Database.

    Notes:
      - cust_po uses CustPOType (nvarchar 25 in this tenant).
      - conum/unit_price legacy columns remain physically available in the
        CSV detail table for backward compatibility, but Contract V2 parser/
        wrapper no longer requires or forwards them.
*/

SET NOCOUNT ON;
GO

IF COL_LENGTH(N'dbo.ue_SMK069_pos_csv_upload_mst', N'cust_po') IS NULL
BEGIN
    ALTER TABLE dbo.ue_SMK069_pos_csv_upload_mst
    ADD cust_po CustPOType NULL;
END;
GO

IF COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_mst', N'cust_po') IS NULL
BEGIN
    ALTER TABLE dbo.ue_SMK069_pos_sales_inbound_mst
    ADD cust_po CustPOType NULL;
END;
GO

IF COL_LENGTH(N'dbo.ue_SMK069_temp_sales_mst', N'cust_po') IS NULL
BEGIN
    ALTER TABLE dbo.ue_SMK069_temp_sales_mst
    ADD cust_po CustPOType NULL;
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.ue_SMK069_pos_field_map_mst
    WHERE source_system = N'POS'
      AND LOWER(LTRIM(RTRIM(source_field))) = N'cust_po'
      AND target_field = N'cust_po'
)
BEGIN
    INSERT INTO dbo.ue_SMK069_pos_field_map_mst
    (
        source_system,
        source_field,
        target_field,
        priority_no,
        is_active
    )
    VALUES
    (
        N'POS',
        N'cust_po',
        N'cust_po',
        1,
        1
    );
END;
GO

/* Verification */
SELECT
    OBJECT_NAME(c.object_id) AS table_name,
    c.name AS column_name,
    TYPE_NAME(c.user_type_id) AS data_type,
    c.max_length
FROM sys.columns AS c
WHERE c.object_id IN
(
    OBJECT_ID(N'dbo.ue_SMK069_pos_csv_upload_mst'),
    OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mst'),
    OBJECT_ID(N'dbo.ue_SMK069_temp_sales_mst')
)
AND c.name = N'cust_po'
ORDER BY table_name;
GO
