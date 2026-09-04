CREATE   PROCEDURE dbo.SMK069BuildShipmentJsonSp
(
    @DN_No       BIGINT,
    @PayloadJson NVARCHAR(MAX) OUTPUT,
    @Success     INT OUTPUT,
    @Infobar     NVARCHAR(4000) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    ------------------------------------------------------------
    -- SITE CONTEXT
    ------------------------------------------------------------
    DECLARE @Site SiteType

    SELECT @Site =
        RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))

    EXEC SetSiteSp @Site, NULL

    ------------------------------------------------------------
    -- INITIAL OUTPUT
    ------------------------------------------------------------
    SET @PayloadJson = NULL;
    SET @Success     = 0;
    SET @Infobar     = NULL;

    ------------------------------------------------------------
    -- Shipment harus ada pada Site aktif dan masih pending
    ------------------------------------------------------------
    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.SMK069_ShipmentAPI_mst
        WHERE site_ref = @Site
          AND DN_No = @DN_No
          AND ISNULL(Api_post, 0) = 0
    )
    BEGIN
        SET @Infobar =
            CONCAT(
                'Shipment DN ',
                CONVERT(VARCHAR(30), @DN_No),
                ' tidak ditemukan pada Site ',
                @Site,
                ' atau sudah diposting.'
            );

        RETURN 0;
    END;

    ------------------------------------------------------------
    -- Harus mempunyai qty > 0
    ------------------------------------------------------------
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
        SET @Infobar =
            CONCAT(
                'Shipment DN ',
                CONVERT(VARCHAR(30), @DN_No),
                ' tidak mempunyai shipment qty > 0 pada Site ',
                @Site,
                '.'
            );

        RETURN 0;
    END;

    ------------------------------------------------------------
    -- Satu DN hanya boleh mempunyai satu DOC_NO
    ------------------------------------------------------------
    DECLARE @DocCount INT;

    SELECT
        @DocCount =
            COUNT(
                DISTINCT NULLIF(
                    LTRIM(RTRIM(doc_no)),
                    ''
                )
            )
    FROM dbo.SMK069_ShipmentAPI_mst
    WHERE site_ref = @Site
      AND DN_No = @DN_No
      AND ISNULL(Api_post, 0) = 0
      AND ISNULL(shipment_qty, 0) > 0;

    IF ISNULL(@DocCount, 0) = 0
    BEGIN
        SET @Infobar =
            CONCAT(
                'Shipment DN ',
                CONVERT(VARCHAR(30), @DN_No),
                ' tidak mempunyai DOC_NO/Customer Order.'
            );

        RETURN 0;
    END;

    IF @DocCount > 1
    BEGIN
        SET @Infobar =
            CONCAT(
                'Shipment DN ',
                CONVERT(VARCHAR(30), @DN_No),
                ' mempunyai lebih dari satu DOC_NO pada Site ',
                @Site,
                '. Payload tidak dibuat.'
            );

        RETURN 0;
    END;

    ------------------------------------------------------------
    -- HEADER
    ------------------------------------------------------------
    DECLARE
        @CustCode      NVARCHAR(50),
        @WhseCode      NVARCHAR(50),
        @DocNo         NVARCHAR(50),
        @DeliveryDate  DATETIME,
        @StoreOrderNo  NVARCHAR(100),
        @StoreCode     NVARCHAR(100),
        @VehicleNumber NVARCHAR(100);

    SELECT TOP (1)
        @CustCode      = cust_code,
        @WhseCode      = whse_code,
        @DocNo         = doc_no,
        @DeliveryDate  = Delivery_date,
        @StoreOrderNo  = Store_Order_No,
        @StoreCode     = store_code,
        @VehicleNumber = Vehicle_number
    FROM dbo.SMK069_ShipmentAPI_mst
    WHERE site_ref = @Site
      AND DN_No = @DN_No
      AND ISNULL(Api_post, 0) = 0
      AND ISNULL(shipment_qty, 0) > 0;

    ------------------------------------------------------------
    -- HEADER VALIDATION
    ------------------------------------------------------------
    IF NULLIF(LTRIM(RTRIM(ISNULL(@CustCode, ''))), '') IS NULL
    BEGIN
        SET @Infobar = 'CUST_CODE kosong.';
        RETURN 0;
    END;

    IF NULLIF(LTRIM(RTRIM(ISNULL(@WhseCode, ''))), '') IS NULL
    BEGIN
        SET @Infobar = 'WHS_CODE kosong.';
        RETURN 0;
    END;

    IF NULLIF(LTRIM(RTRIM(ISNULL(@DocNo, ''))), '') IS NULL
    BEGIN
        SET @Infobar = 'DOC_NO kosong.';
        RETURN 0;
    END;

    IF @DeliveryDate IS NULL
    BEGIN
        SET @Infobar = 'DELIVERY_DATE kosong.';
        RETURN 0;
    END;

    IF NULLIF(LTRIM(RTRIM(ISNULL(@StoreOrderNo, ''))), '') IS NULL
    BEGIN
        SET @Infobar = 'STORE_ORDER_NO kosong.';
        RETURN 0;
    END;

    ------------------------------------------------------------
    -- PRODUCT VALIDATION
    ------------------------------------------------------------
    IF EXISTS
    (
        SELECT 1
        FROM dbo.SMK069_ShipmentAPI_mst
        WHERE site_ref = @Site
          AND DN_No = @DN_No
          AND ISNULL(Api_post, 0) = 0
          AND ISNULL(shipment_qty, 0) > 0
          AND NULLIF(
                LTRIM(RTRIM(ISNULL(product_code, ''))),
                ''
              ) IS NULL
    )
    BEGIN
        SET @Infobar =
            'Terdapat detail shipment dengan PRODUCT_CODE kosong.';

        RETURN 0;
    END;

    ------------------------------------------------------------
    -- BUILD JSON
    ------------------------------------------------------------
    SELECT @PayloadJson =
    (
        SELECT
            @CustCode AS [CUST_CODE],
            @WhseCode AS [WHS_CODE],
            @DocNo AS [DOC_NO],
            CONVERT(VARCHAR(30), @DN_No) AS [DN_NO],

            CONVERT(CHAR(10), @DeliveryDate, 23)
                AS [DELIVERY_DATE],

            @StoreOrderNo AS [STORE_ORDER_NO],

            ISNULL(@StoreCode, '')
                AS [STORE_CODE],

            ISNULL(@VehicleNumber, '')
                AS [VEHICLE_NUMBER],

            JSON_QUERY
            (
                (
                    SELECT
                        d.product_code AS [PRODUCT_CODE],

                        CONVERT(
                            DECIMAL(19,8),
                            d.shipment_qty
                        ) AS [SHIPMENT_QTY],

                        d.UOM AS [UOM],

                        CONVERT(
                            DECIMAL(19,8),
                            d.Price
                        ) AS [PRICE],

                        d.Batch AS [BATCH],

                        CASE
                            WHEN d.Expiry_date IS NULL
                                THEN NULL
                            ELSE
                                CONVERT(
                                    CHAR(10),
                                    d.Expiry_date,
                                    23
                                )
                        END AS [EXPIRY_DATE]

                    FROM dbo.SMK069_ShipmentAPI_mst d
                    WHERE d.site_ref = @Site
                      AND d.DN_No = @DN_No
                      AND ISNULL(d.Api_post, 0) = 0
                      AND ISNULL(d.shipment_qty, 0) > 0

                    ORDER BY
                        d.product_code,
                        d.Batch

                    FOR JSON PATH, INCLUDE_NULL_VALUES
                )
            ) AS [DETAIL]

        FOR JSON PATH,
            WITHOUT_ARRAY_WRAPPER,
            INCLUDE_NULL_VALUES
    );

    ------------------------------------------------------------
    -- SUCCESS
    ------------------------------------------------------------
    SET @Success = 1;

    IF NULLIF(LTRIM(RTRIM(ISNULL(@StoreCode, ''))), '') IS NULL
    BEGIN
        SET @Infobar =
            CONCAT(
                'Shipment DN ',
                CONVERT(VARCHAR(30), @DN_No),
                ' berhasil dibuat menjadi JSON untuk Site ',
                @Site,
                '. WARNING: STORE_CODE masih kosong.'
            );
    END
    ELSE
    BEGIN
        SET @Infobar =
            CONCAT(
                'Shipment DN ',
                CONVERT(VARCHAR(30), @DN_No),
                ' berhasil dibuat menjadi JSON untuk Site ',
                @Site,
                '.'
            );
    END;

    RETURN 0;
END;
