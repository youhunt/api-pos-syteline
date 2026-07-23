CREATE OR ALTER PROCEDURE dbo.SMKRSCPosCreateManualInboundSp
    @SourceSystem    nvarchar(30),
    @OutletCode      nvarchar(20) = NULL,
    @SourceReference nvarchar(100) = NULL,
    @PayloadVersion  nvarchar(20) = N'POS_MINIMAL_V1',
    @InboundId       uniqueidentifier OUTPUT,
    @RequestId       nvarchar(50) OUTPUT,
    @Infobar         nvarchar(1000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Infobar = NULL;
    SET @InboundId = NULL;
    SET @RequestId = NULL;

    BEGIN TRY
        SET @SourceSystem = NULLIF(LTRIM(RTRIM(@SourceSystem)), N'');
        SET @OutletCode = NULLIF(LTRIM(RTRIM(@OutletCode)), N'');
        SET @SourceReference = NULLIF(LTRIM(RTRIM(@SourceReference)), N'');
        SET @PayloadVersion = NULLIF(LTRIM(RTRIM(@PayloadVersion)), N'');

        IF @SourceSystem IS NULL
        BEGIN
            SET @Infobar = N'Source System wajib diisi.';
            RETURN 16;
        END;

        IF @PayloadVersion IS NULL
            SET @PayloadVersion = N'POS_MINIMAL_V1';

        SET @InboundId = NEWID();
        SET @RequestId = CONCAT(
            N'MAN-',
            CONVERT(char(8), GETDATE(), 112),
            N'-',
            REPLACE(CONVERT(char(8), GETDATE(), 108), N':', N''),
            N'-',
            RIGHT(REPLACE(CONVERT(nvarchar(36), @InboundId), N'-', N''), 8)
        );

        INSERT INTO dbo.ue_SMK_RSC_POS_Inbound_mst
        (
            inbound_id,
            request_id,
            correlation_id,
            source_system,
            source_reference,
            outlet_code,
            endpoint_name,
            http_method,
            content_type,
            payload_version,
            payload_format,
            storage_mode,
            content_length,
            received_date,
            stat,
            row_count,
            accepted_count,
            rejected_count,
            response_code,
            response_message,
            retry_count,
            purged_flag
        )
        VALUES
        (
            @InboundId,
            @RequestId,
            @RequestId,
            @SourceSystem,
            @SourceReference,
            @OutletCode,
            N'MANUAL_CSV',
            N'UPLOAD',
            N'text/csv',
            @PayloadVersion,
            N'C',
            N'N',
            0,
            GETDATE(),
            N'R',
            0,
            0,
            0,
            201,
            N'Manual inbound created. Attach a CSV file before validation.',
            0,
            0
        );

        IF @@ROWCOUNT <> 1
        BEGIN
            SET @Infobar = N'Inbound record tidak berhasil dibuat.';
            RETURN 16;
        END;

        SET @Infobar = CONCAT(N'Manual inbound berhasil dibuat. Request ID: ', @RequestId);
        RETURN 0;
    END TRY
    BEGIN CATCH
        SET @InboundId = NULL;
        SET @RequestId = NULL;
        SET @Infobar = CONCAT(N'CreateManualInbound gagal: ', ERROR_MESSAGE());
        RETURN 16;
    END CATCH;
END;
