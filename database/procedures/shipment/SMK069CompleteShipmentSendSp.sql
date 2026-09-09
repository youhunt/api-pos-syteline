CREATE OR ALTER PROCEDURE dbo.SMK069CompleteShipmentSendSp
(
    @LogRowPointer UNIQUEIDENTIFIER,
    @HttpCode      INT,
    @ResponseJson  NVARCHAR(MAX),
    @IsSuccess     INT,
    @Success       INT OUTPUT,
    @Infobar       NVARCHAR(4000) OUTPUT
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
    SET @Success = 0;
    SET @Infobar = NULL;

    /* SMK069-COMPLETE-DN-STRING-R1 */
    DECLARE @ShipmentDn NVARCHAR(40);
    DECLARE @ShipmentId BIGINT;

    ------------------------------------------------------------
    -- LOG HARUS BERASAL DARI SITE AKTIF
    ------------------------------------------------------------
    SELECT
        @ShipmentDn = NULLIF(
            LTRIM(RTRIM(CONVERT(NVARCHAR(40), ShipmentId))),
            N''
        )
    FROM dbo.ue_SMK069_shipment_api_log_mst
    WHERE SiteRef = @Site
      AND RowPointer = @LogRowPointer;

    IF @ShipmentDn IS NULL
    BEGIN
        SET @Infobar =
            CONCAT(
                'Shipment API log tidak ditemukan pada Site ',
                @Site,
                '.'
            );

        RETURN 0;
    END;

    ------------------------------------------------------------
    -- RESOLVE OUTBOUND DN -> STANDARD NUMERIC SHIPMENT KEY
    -- Current View contract:
    --   PLG       => P963 + shipment_id
    --   non-PLG   => R975 + shipment_id
    ------------------------------------------------------------
    SELECT
        @ShipmentId = sh.shipment_id
    FROM dbo.shipment_mst AS sh
    WHERE sh.site_ref = @Site
      AND CAST(
              CONCAT(
                  IIF(sh.whse = 'PLG', 'P963', 'R975'),
                  sh.shipment_id
              )
              AS NVARCHAR(40)
          ) = @ShipmentDn;

    /* Backward compatibility for historical numeric-only ShipmentId logs. */
    IF @ShipmentId IS NULL
        SET @ShipmentId = TRY_CONVERT(BIGINT, @ShipmentDn);

    IF @ShipmentId IS NULL
    BEGIN
        SET @Infobar =
            CONCAT(
                'Shipment DN ',
                @ShipmentDn,
                ' pada Site ',
                @Site,
                ' tidak dapat dipetakan ke shipment_mst.shipment_id.'
            );

        RETURN 0;
    END;

    ------------------------------------------------------------
    -- SUCCESS
    ------------------------------------------------------------
    IF ISNULL(@IsSuccess, 0) = 1
    BEGIN
        UPDATE dbo.ue_SMK069_shipment_api_log_mst
        SET
            ResponseDate = GETDATE(),
            ResponseHttpCode = @HttpCode,
            ResponseJson = @ResponseJson,
            ProcessStatus = 'S',
            ErrorMessage = NULL,
            RecordDate = GETDATE(),
            UpdatedBy = SUSER_SNAME()
        WHERE SiteRef = @Site
          AND RowPointer = @LogRowPointer;

        UPDATE dbo.shipment_mst
        SET
            SMK069_Uf_api_post = 1,
            SMK069_Uf_api_post_date = GETDATE()
        WHERE site_ref = @Site
          AND shipment_id = @ShipmentId;

        SET @Success = 1;

        SET @Infobar =
            CONCAT(
                'Shipment DN ',
                CONVERT(VARCHAR(40), @ShipmentDn),
                ' pada Site ',
                @Site,
                ' berhasil diposting ke POS.'
            );

        RETURN 0;
    END;

    ------------------------------------------------------------
    -- ERROR
    ------------------------------------------------------------
    UPDATE dbo.ue_SMK069_shipment_api_log_mst
    SET
        ResponseDate = GETDATE(),
        ResponseHttpCode = @HttpCode,
        ResponseJson = @ResponseJson,
        ProcessStatus = 'E',
        ErrorMessage =
            ISNULL(
                @ResponseJson,
                'API shipment gagal.'
            ),
        RetryCount =
            ISNULL(RetryCount, 0) + 1,
        RecordDate = GETDATE(),
        UpdatedBy = SUSER_SNAME()
    WHERE SiteRef = @Site
      AND RowPointer = @LogRowPointer;

    ------------------------------------------------------------
    -- TETAP PENDING
    ------------------------------------------------------------
    UPDATE dbo.shipment_mst
    SET
        SMK069_Uf_api_post = 0,
        SMK069_Uf_api_post_date = NULL
    WHERE site_ref = @Site
      AND shipment_id = @ShipmentId;

    SET @Success = 0;

    SET @Infobar =
        CONCAT(
            'Shipment DN ',
            CONVERT(VARCHAR(40), @ShipmentDn),
            ' pada Site ',
            @Site,
            ' gagal dikirim ke POS.'
        );

    RETURN 0;
END;
