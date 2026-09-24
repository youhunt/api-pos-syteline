/* PROD migration artifact
   Source: database/patches/shipment/2026-09-09-smk069-15-fix-complete-shipment-dn-string.sql
   SyteLine Cloud Apply Database: one batch, NO GO.
*/
/* =============================================================================
   SMK069 - Shipment Patch 15
   Fix Complete Shipment prefixed DN -> numeric shipment_id mapping
   -----------------------------------------------------------------------------
   Date    : 2026-09-09
   Scope   : Shipment Outbound SyteLine -> POS API only
   Object  : dbo.SMK069CompleteShipmentSendSp

   PROVEN ROOT CAUSE
   -----------------
   Current tenant Complete source declares:

       DECLARE @ShipmentId BIGINT;

   and then reads:

       SELECT @ShipmentId = ShipmentId
       FROM dbo.ue_SMK069_shipment_api_log_mst

   Current API log ShipmentId is the outbound DN string (for example P96330),
   therefore SQL Server tries to convert NVARCHAR 'P96330' to BIGINT and throws:

       Error converting data type nvarchar to bigint.
       dbo.SMK069CompleteShipmentSendSp:36

   CURRENT TENANT DN CONTRACT
   --------------------------
   Tenant View evidence captured 9 Sep 2026:

       CAST(
           CONCAT(
               IIF(sh.whse = 'PLG', 'P963', 'R975'),
               sh.shipment_id
           )
           AS nvarchar(10)
       ) AS DN_No

   Therefore:

       P96330 = prefix P963 + shipment_mst.shipment_id 30
       P96331 = prefix P963 + shipment_mst.shipment_id 31
       P96332 = prefix P963 + shipment_mst.shipment_id 32

   IMPORTANT: P96330 is NOT shipment_id 96330.

   FIX
   ---
   1. Keep the log/outbound DN as NVARCHAR in @ShipmentDn.
   2. Resolve the standard numeric shipment_mst.shipment_id by reproducing the
      CURRENT tenant DN expression against shipment_mst.
   3. Keep backward compatibility for historical numeric-only log ShipmentId.
   4. Update shipment_mst using the resolved numeric key.
   5. Infobar continues to show the outbound DN (P963xx/R975xx), not numeric key.

   SAFETY
   ------
   * Does NOT Reset Retry.
   * Does NOT invoke HTTP / sender.
   * Does NOT change Shipment View.
   * Does NOT change API endpoint configuration.
   * Does NOT change Complete parameters / IDO signature.
   * Guarded against an unexpected tenant source or DN mapping drift.
   * One executable Apply Database batch, NO GO.
   ============================================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE
        @CompleteDef NVARCHAR(MAX),
        @ViewDef     NVARCHAR(MAX);

    SET @CompleteDef = OBJECT_DEFINITION(
        OBJECT_ID(N'dbo.SMK069CompleteShipmentSendSp', N'P')
    );

    SET @ViewDef = OBJECT_DEFINITION(
        OBJECT_ID(N'dbo.SMK069_ShipmentAPI_mst', N'V')
    );

    IF @CompleteDef IS NULL
        RAISERROR('dbo.SMK069CompleteShipmentSendSp tidak ditemukan / definition tidak terbaca.', 16, 1);

    IF @ViewDef IS NULL
        RAISERROR('dbo.SMK069_ShipmentAPI_mst tidak ditemukan / definition tidak terbaca.', 16, 1);

    /* Idempotent re-apply. */
    IF CHARINDEX(N'SMK069-COMPLETE-DN-STRING-R1', @CompleteDef) = 0
    BEGIN
        /* Guard exact failure class captured from current tenant. */
        IF CHARINDEX(N'DECLARE @ShipmentId BIGINT', @CompleteDef) = 0
           OR CHARINDEX(N'@ShipmentId = ShipmentId', @CompleteDef) = 0
        BEGIN
            RAISERROR(
                'Tenant Complete source tidak lagi cocok dengan baseline Patch 15. Patch dihentikan; capture ulang source sebelum mengubah.',
                16,
                1
            );
        END;

        /* Guard current outbound DN contract before duplicating it in Complete. */
        IF CHARINDEX(N'''P963''', @ViewDef) = 0
           OR CHARINDEX(N'''R975''', @ViewDef) = 0
           OR CHARINDEX(N'sh.shipment_id', @ViewDef) = 0
           OR CHARINDEX(N'DN_No', @ViewDef) = 0
        BEGIN
            RAISERROR(
                'Current Shipment View tidak lagi menunjukkan contract DN P963/R975 + shipment_id. Patch 15 dihentikan.',
                16,
                1
            );
        END;

        EXEC sys.sp_executesql N'
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
            N''''
        )
    FROM dbo.ue_SMK069_shipment_api_log_mst
    WHERE SiteRef = @Site
      AND RowPointer = @LogRowPointer;

    IF @ShipmentDn IS NULL
    BEGIN
        SET @Infobar =
            CONCAT(
                ''Shipment API log tidak ditemukan pada Site '',
                @Site,
                ''.''
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
                  IIF(sh.whse = ''PLG'', ''P963'', ''R975''),
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
                ''Shipment DN '',
                @ShipmentDn,
                '' pada Site '',
                @Site,
                '' tidak dapat dipetakan ke shipment_mst.shipment_id.''
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
            ProcessStatus = ''S'',
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
                ''Shipment DN '',
                CONVERT(VARCHAR(40), @ShipmentDn),
                '' pada Site '',
                @Site,
                '' berhasil diposting ke POS.''
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
        ProcessStatus = ''E'',
        ErrorMessage =
            ISNULL(
                @ResponseJson,
                ''API shipment gagal.''
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
            ''Shipment DN '',
            CONVERT(VARCHAR(40), @ShipmentDn),
            '' pada Site '',
            @Site,
            '' gagal dikirim ke POS.''
        );

    RETURN 0;
END;';
    END;

    SET @CompleteDef = OBJECT_DEFINITION(
        OBJECT_ID(N'dbo.SMK069CompleteShipmentSendSp', N'P')
    );

    IF CHARINDEX(N'SMK069-COMPLETE-DN-STRING-R1', ISNULL(@CompleteDef, N'')) = 0
        RAISERROR('Patch 15 marker tidak ditemukan setelah apply.', 16, 1);

    IF CHARINDEX(N'@ShipmentId = ShipmentId', ISNULL(@CompleteDef, N'')) > 0
        RAISERROR('Old nvarchar-to-bigint assignment masih ada setelah Patch 15.', 16, 1);

    IF CHARINDEX(N'@ShipmentDn', ISNULL(@CompleteDef, N'')) = 0
       OR CHARINDEX(N'''P963''', ISNULL(@CompleteDef, N'')) = 0
       OR CHARINDEX(N'''R975''', ISNULL(@CompleteDef, N'')) = 0
        RAISERROR('Patch 15 DN mapping assertion gagal.', 16, 1);

    COMMIT TRANSACTION;

    PRINT 'OK - Patch 15 applied.';
    PRINT 'Complete sekarang membaca outbound DN sebagai NVARCHAR.';
    PRINT 'P963/R975 DN dipetakan ke numeric shipment_mst.shipment_id memakai current tenant View contract.';
    PRINT 'Contoh: P96330 -> shipment_id 30, BUKAN 96330.';
    PRINT 'Patch ini TIDAK Reset Retry dan TIDAK melakukan HTTP call.';
    PRINT 'JANGAN retry sampai HTTP 404 endpoint juga dibereskan.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
