/*
    SMK069 Shipment -> KACS payload mapping V1
    Date: 2026-09-04

    Purpose:
    - keep Shipment outbound mapping separate from POS inbound/Customer Order mapping;
    - map SyteLine customer/warehouse/UOM into KACS codes;
    - expose numeric UOM in SMK069_ShipmentAPI_mst;
    - reject missing KACS Shipment mappings before outbound HTTP.

    IMPORTANT:
    This patch creates mapping structures but DOES NOT hardcode the sample
    KACS values S060 / R950 / R919 / 1. Populate mappings with real business
    codes for the tenant before positive UAT.
*/

SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.ue_SMK069_shipment_customer_map_mst', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ue_SMK069_shipment_customer_map_mst
    (
        SiteRef          NVARCHAR(8)  NOT NULL,
        SytelineCustNum  NVARCHAR(50) NOT NULL,
        KacsCustCode     NVARCHAR(50) NOT NULL,
        KacsStoreCode    NVARCHAR(50) NOT NULL,
        IsActive         BIT          NOT NULL CONSTRAINT DF_ue_SMK069_ship_cust_map_IsActive DEFAULT (1),
        CreateDate       DATETIME     NOT NULL CONSTRAINT DF_ue_SMK069_ship_cust_map_CreateDate DEFAULT (GETDATE()),
        RecordDate       DATETIME     NOT NULL CONSTRAINT DF_ue_SMK069_ship_cust_map_RecordDate DEFAULT (GETDATE()),
        RowPointer       UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_ue_SMK069_ship_cust_map_RowPointer DEFAULT (NEWID()),

        CONSTRAINT PK_ue_SMK069_shipment_customer_map_mst
            PRIMARY KEY (RowPointer),

        CONSTRAINT UQ_ue_SMK069_shipment_customer_map_mst
            UNIQUE (SiteRef, SytelineCustNum),

        CONSTRAINT CK_ue_SMK069_ship_cust_map_CustCode
            CHECK (LEN(LTRIM(RTRIM(KacsCustCode))) > 0),

        CONSTRAINT CK_ue_SMK069_ship_cust_map_StoreCode
            CHECK (LEN(LTRIM(RTRIM(KacsStoreCode))) > 0)
    );
END;

IF OBJECT_ID(N'dbo.ue_SMK069_shipment_whse_map_mst', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ue_SMK069_shipment_whse_map_mst
    (
        SiteRef       NVARCHAR(8)  NOT NULL,
        SytelineWhse  NVARCHAR(50) NOT NULL,
        KacsWhsCode   NVARCHAR(50) NOT NULL,
        IsActive      BIT          NOT NULL CONSTRAINT DF_ue_SMK069_ship_whse_map_IsActive DEFAULT (1),
        CreateDate    DATETIME     NOT NULL CONSTRAINT DF_ue_SMK069_ship_whse_map_CreateDate DEFAULT (GETDATE()),
        RecordDate    DATETIME     NOT NULL CONSTRAINT DF_ue_SMK069_ship_whse_map_RecordDate DEFAULT (GETDATE()),
        RowPointer    UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_ue_SMK069_ship_whse_map_RowPointer DEFAULT (NEWID()),

        CONSTRAINT PK_ue_SMK069_shipment_whse_map_mst
            PRIMARY KEY (RowPointer),

        CONSTRAINT UQ_ue_SMK069_shipment_whse_map_mst
            UNIQUE (SiteRef, SytelineWhse),

        CONSTRAINT CK_ue_SMK069_ship_whse_map_WhsCode
            CHECK (LEN(LTRIM(RTRIM(KacsWhsCode))) > 0)
    );
END;

IF OBJECT_ID(N'dbo.ue_SMK069_shipment_uom_map_mst', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ue_SMK069_shipment_uom_map_mst
    (
        SiteRef       NVARCHAR(8)  NOT NULL,
        SytelineUom   NVARCHAR(50) NOT NULL,
        KacsUom       INT          NOT NULL,
        IsActive      BIT          NOT NULL CONSTRAINT DF_ue_SMK069_ship_uom_map_IsActive DEFAULT (1),
        CreateDate    DATETIME     NOT NULL CONSTRAINT DF_ue_SMK069_ship_uom_map_CreateDate DEFAULT (GETDATE()),
        RecordDate    DATETIME     NOT NULL CONSTRAINT DF_ue_SMK069_ship_uom_map_RecordDate DEFAULT (GETDATE()),
        RowPointer    UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_ue_SMK069_ship_uom_map_RowPointer DEFAULT (NEWID()),

        CONSTRAINT PK_ue_SMK069_shipment_uom_map_mst
            PRIMARY KEY (RowPointer),

        CONSTRAINT UQ_ue_SMK069_shipment_uom_map_mst
            UNIQUE (SiteRef, SytelineUom),

        CONSTRAINT CK_ue_SMK069_ship_uom_map_KacsUom
            CHECK (KacsUom > 0)
    );
END;

EXEC(N'
CREATE OR ALTER VIEW dbo.SMK069_ShipmentAPI_mst
AS
SELECT
    sh.site_ref AS site_ref,
    NULLIF(LTRIM(RTRIM(cmap.KacsCustCode)), '''') AS cust_code,
    NULLIF(LTRIM(RTRIM(wmap.KacsWhsCode)), '''') AS whse_code,
    co.co_num AS doc_no,
    sh.shipment_id AS DN_No,
    sh.ship_date AS Delivery_date,
    co.cust_po AS Store_Order_No,
    NULLIF(LTRIM(RTRIM(cmap.KacsStoreCode)), '''') AS store_code,
    sh.veh_num AS Vehicle_number,
    coi.item AS product_code,
    shipseq.qty_shipped AS shipment_qty,
    umap.KacsUom AS UOM,
    coi.price AS Price,
    shipseq.lot AS Batch,
    lot.exp_date AS Expiry_date,
    ISNULL(sh.SMK069_Uf_API_post, 0) AS Api_post,
    sh.SMK069_Uf_API_post_date AS Api_post_date
FROM dbo.shipment_mst sh
LEFT JOIN dbo.shipment_line_mst shl
    ON shl.shipment_id = sh.shipment_id
   AND shl.site_ref = sh.site_ref
LEFT JOIN dbo.coitem_mst coi
    ON coi.co_num = shl.ref_num
   AND coi.co_line = shl.ref_line_suf
   AND coi.co_release = shl.ref_release
   AND coi.site_ref = sh.site_ref
LEFT JOIN dbo.co_mst co
    ON co.co_num = coi.co_num
   AND co.site_ref = coi.site_ref
LEFT JOIN dbo.shipment_seq_mst shipseq
    ON shipseq.shipment_id = shl.shipment_id
   AND shipseq.shipment_line = shl.shipment_line
   AND shipseq.site_ref = sh.site_ref
LEFT JOIN dbo.lot_mst lot
    ON lot.lot = shipseq.lot
   AND lot.item = coi.item
   AND lot.site_ref = sh.site_ref
LEFT JOIN dbo.ue_SMK069_shipment_customer_map_mst cmap
    ON cmap.SiteRef = sh.site_ref
   AND cmap.SytelineCustNum = sh.cust_num
   AND cmap.IsActive = 1
LEFT JOIN dbo.ue_SMK069_shipment_whse_map_mst wmap
    ON wmap.SiteRef = sh.site_ref
   AND wmap.SytelineWhse = sh.whse
   AND wmap.IsActive = 1
LEFT JOIN dbo.ue_SMK069_shipment_uom_map_mst umap
    ON umap.SiteRef = sh.site_ref
   AND umap.SytelineUom = coi.u_m
   AND umap.IsActive = 1;
');

EXEC(N'
CREATE OR ALTER PROCEDURE dbo.SMK069BuildShipmentJsonSp
(
    @DN_No       BIGINT,
    @PayloadJson NVARCHAR(MAX) OUTPUT,
    @Success     INT OUTPUT,
    @Infobar     NVARCHAR(4000) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Site SiteType;
    SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));
    EXEC SetSiteSp @Site, NULL;

    SET @PayloadJson = NULL;
    SET @Success = 0;
    SET @Infobar = NULL;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.SMK069_ShipmentAPI_mst
        WHERE site_ref = @Site
          AND DN_No = @DN_No
          AND ISNULL(Api_post, 0) = 0
    )
    BEGIN
        SET @Infobar = CONCAT(''Shipment DN '', CONVERT(VARCHAR(30), @DN_No), '' tidak ditemukan pada Site '', @Site, '' atau sudah diposting.'');
        RETURN 0;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.SMK069_ShipmentAPI_mst
        WHERE site_ref = @Site
          AND DN_No = @DN_No
          AND ISNULL(Api_post, 0) = 0
          AND ISNULL(shipment_qty, 0) > 0
    )
    BEGIN
        SET @Infobar = CONCAT(''Shipment DN '', CONVERT(VARCHAR(30), @DN_No), '' tidak mempunyai shipment qty > 0 pada Site '', @Site, ''.'');
        RETURN 0;
    END;

    DECLARE @DocCount INT;
    SELECT @DocCount = COUNT(DISTINCT NULLIF(LTRIM(RTRIM(doc_no)), ''''))
    FROM dbo.SMK069_ShipmentAPI_mst
    WHERE site_ref = @Site
      AND DN_No = @DN_No
      AND ISNULL(Api_post, 0) = 0
      AND ISNULL(shipment_qty, 0) > 0;

    IF ISNULL(@DocCount, 0) = 0
    BEGIN
        SET @Infobar = CONCAT(''Shipment DN '', CONVERT(VARCHAR(30), @DN_No), '' tidak mempunyai DOC_NO/Customer Order.'');
        RETURN 0;
    END;

    IF @DocCount > 1
    BEGIN
        SET @Infobar = CONCAT(''Shipment DN '', CONVERT(VARCHAR(30), @DN_No), '' mempunyai lebih dari satu DOC_NO pada Site '', @Site, ''. Payload tidak dibuat.'');
        RETURN 0;
    END;

    DECLARE
        @CustCode NVARCHAR(50),
        @WhseCode NVARCHAR(50),
        @DocNo NVARCHAR(50),
        @DeliveryDate DATETIME,
        @StoreOrderNo NVARCHAR(100),
        @StoreCode NVARCHAR(100),
        @VehicleNumber NVARCHAR(100);

    SELECT TOP (1)
        @CustCode = cust_code,
        @WhseCode = whse_code,
        @DocNo = doc_no,
        @DeliveryDate = Delivery_date,
        @StoreOrderNo = Store_Order_No,
        @StoreCode = store_code,
        @VehicleNumber = Vehicle_number
    FROM dbo.SMK069_ShipmentAPI_mst
    WHERE site_ref = @Site
      AND DN_No = @DN_No
      AND ISNULL(Api_post, 0) = 0
      AND ISNULL(shipment_qty, 0) > 0;

    IF NULLIF(LTRIM(RTRIM(ISNULL(@CustCode, ''''))), '''') IS NULL
    BEGIN
        SET @Infobar = ''CUST_CODE KACS kosong/belum dimapping pada Shipment.'';
        RETURN 0;
    END;

    IF NULLIF(LTRIM(RTRIM(ISNULL(@WhseCode, ''''))), '''') IS NULL
    BEGIN
        SET @Infobar = ''WHS_CODE KACS kosong/belum dimapping pada Shipment.'';
        RETURN 0;
    END;

    IF NULLIF(LTRIM(RTRIM(ISNULL(@DocNo, ''''))), '''') IS NULL
    BEGIN
        SET @Infobar = ''DOC_NO kosong.'';
        RETURN 0;
    END;

    IF @DeliveryDate IS NULL
    BEGIN
        SET @Infobar = ''DELIVERY_DATE kosong.'';
        RETURN 0;
    END;

    IF NULLIF(LTRIM(RTRIM(ISNULL(@StoreOrderNo, ''''))), '''') IS NULL
    BEGIN
        SET @Infobar = ''STORE_ORDER_NO kosong.'';
        RETURN 0;
    END;

    IF NULLIF(LTRIM(RTRIM(ISNULL(@StoreCode, ''''))), '''') IS NULL
    BEGIN
        SET @Infobar = ''STORE_CODE KACS kosong/belum dimapping pada Shipment.'';
        RETURN 0;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.SMK069_ShipmentAPI_mst
        WHERE site_ref = @Site
          AND DN_No = @DN_No
          AND ISNULL(Api_post, 0) = 0
          AND ISNULL(shipment_qty, 0) > 0
          AND NULLIF(LTRIM(RTRIM(ISNULL(product_code, ''''))), '''') IS NULL
    )
    BEGIN
        SET @Infobar = ''Terdapat detail shipment dengan PRODUCT_CODE kosong.'';
        RETURN 0;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.SMK069_ShipmentAPI_mst
        WHERE site_ref = @Site
          AND DN_No = @DN_No
          AND ISNULL(Api_post, 0) = 0
          AND ISNULL(shipment_qty, 0) > 0
          AND (UOM IS NULL OR UOM <= 0)
    )
    BEGIN
        SET @Infobar = ''Terdapat detail shipment dengan UOM KACS kosong/belum dimapping.'';
        RETURN 0;
    END;

    SELECT @PayloadJson =
    (
        SELECT
            @CustCode AS [CUST_CODE],
            @WhseCode AS [WHS_CODE],
            @DocNo AS [DOC_NO],
            CONVERT(VARCHAR(30), @DN_No) AS [DN_NO],
            CONVERT(CHAR(10), @DeliveryDate, 23) AS [DELIVERY_DATE],
            @StoreOrderNo AS [STORE_ORDER_NO],
            @StoreCode AS [STORE_CODE],
            ISNULL(@VehicleNumber, '''') AS [VEHICLE_NUMBER],
            JSON_QUERY
            (
                (
                    SELECT
                        d.product_code AS [PRODUCT_CODE],
                        CONVERT(DECIMAL(19,8), d.shipment_qty) AS [SHIPMENT_QTY],
                        d.UOM AS [UOM],
                        CONVERT(DECIMAL(19,8), d.Price) AS [PRICE],
                        d.Batch AS [BATCH],
                        CASE
                            WHEN d.Expiry_date IS NULL THEN NULL
                            ELSE CONVERT(CHAR(10), d.Expiry_date, 23)
                        END AS [EXPIRY_DATE]
                    FROM dbo.SMK069_ShipmentAPI_mst d
                    WHERE d.site_ref = @Site
                      AND d.DN_No = @DN_No
                      AND ISNULL(d.Api_post, 0) = 0
                      AND ISNULL(d.shipment_qty, 0) > 0
                    ORDER BY d.product_code, d.Batch
                    FOR JSON PATH, INCLUDE_NULL_VALUES
                )
            ) AS [DETAIL]
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
    );

    SET @Success = 1;
    SET @Infobar = CONCAT(''Shipment DN '', CONVERT(VARCHAR(30), @DN_No), '' berhasil dibuat menjadi JSON KACS untuk Site '', @Site, ''.'');
    RETURN 0;
END;
');

-- Verification only: run in Query Execution after real mappings are populated.
SELECT
    SiteRef,
    SytelineCustNum,
    KacsCustCode,
    KacsStoreCode,
    IsActive
FROM dbo.ue_SMK069_shipment_customer_map_mst
ORDER BY SiteRef, SytelineCustNum;

SELECT
    SiteRef,
    SytelineWhse,
    KacsWhsCode,
    IsActive
FROM dbo.ue_SMK069_shipment_whse_map_mst
ORDER BY SiteRef, SytelineWhse;

SELECT
    SiteRef,
    SytelineUom,
    KacsUom,
    IsActive
FROM dbo.ue_SMK069_shipment_uom_map_mst
ORDER BY SiteRef, SytelineUom;
