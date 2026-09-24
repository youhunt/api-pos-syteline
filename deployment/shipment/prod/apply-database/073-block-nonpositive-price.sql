/* PROD migration artifact
   Source: database/patches/shipment/2026-09-21-smk069-22-block-nonpositive-price.sql
   SyteLine Cloud Apply Database: one batch, NO GO.
*/
/* =============================================================================
   SMK069 - Shipment Patch 22
   Block non-positive PRICE before Shipment API POST
   -----------------------------------------------------------------------------
   Date    : 2026-09-21
   Scope   : Shipment Outbound SyteLine -> POS API only
   Object  : dbo.SMK069BuildShipmentJsonSp

   BUSINESS CHANGE
   ---------------
   Previous behavior:
       detail PRICE NULL / 0 / negative
       -> Build could continue
       -> JSON could contain PRICE 0 / null / negative
       -> Shipment could reach POS API

   New behavior:
       any pending detail with shipment_qty > 0 and PRICE <= 0 or NULL
       -> Build stops locally
       -> @Success remains 0
       -> no Shipment HTTP POST is performed for that DN

   Example currently observed:
       DN_NO        = P963221
       PRODUCT_CODE = AC20003B
       PRICE        = 0.00000000

   SAFETY
   ------
   * Tenant-preserving: reads current dbo.SMK069BuildShipmentJsonSp from
     OBJECT_DEFINITION and inserts only one validation guard.
   * Does NOT replace the tenant procedure with the stale repository base body.
   * @DN_No must already use the current prefixed String contract.
   * Requires verified DOC_NO non-blocking Patch 14 Rev.2.
   * Requires STORE_ORDER_NO non-blocking Patch 20.
   * Shipment View is NOT changed.
   * BATCH / EXPIRY_DATE nullability is NOT changed.
   * Retry policy is NOT changed.
   * No Reset Retry, TaskMan submit, or HTTP call is performed by this patch.
   * Designed for Infor Apply Database: ONE executable batch, NO GO.
   ============================================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE
        @BuildObjectId INT,
        @BuildDef      NVARCHAR(MAX),
        @BuildNew      NVARCHAR(MAX),
        @BuildNamePos  INT,
        @BuildJsonPos  INT,
        @DnType        SYSNAME;

    SET @BuildObjectId = OBJECT_ID(N'dbo.SMK069BuildShipmentJsonSp', N'P');

    IF @BuildObjectId IS NULL
    BEGIN
        RAISERROR('dbo.SMK069BuildShipmentJsonSp tidak ditemukan.', 16, 1);
    END;

    /* Preserve the current prefixed DN contract: P963xx / R975xx. */
    SELECT @DnType = TYPE_NAME(user_type_id)
    FROM sys.parameters
    WHERE object_id = @BuildObjectId
      AND parameter_id = 1
      AND name = N'@DN_No';

    IF LOWER(ISNULL(@DnType, N'')) NOT IN (N'nvarchar', N'varchar', N'nchar', N'char')
    BEGIN
        RAISERROR(
            'SMK069BuildShipmentJsonSp.@DN_No bukan String. Patch 22 dihentikan untuk mencegah regresi DN P963xx/R975xx.',
            16, 1
        );
    END;

    SET @BuildDef = OBJECT_DEFINITION(@BuildObjectId);

    IF @BuildDef IS NULL
    BEGIN
        RAISERROR('Definition dbo.SMK069BuildShipmentJsonSp tidak dapat dibaca.', 16, 1);
    END;

    /* Preserve already-verified tenant behavior. */
    IF CHARINDEX(N'SMK069-DOC-NONBLOCKING-R2', @BuildDef) = 0
    BEGIN
        RAISERROR(
            'Patch 14 Rev.2 marker tidak ditemukan pada tenant Build. Patch 22 dihentikan.',
            16, 1
        );
    END;

    IF CHARINDEX(N'SMK069-STORE-ORDER-NONBLOCKING-R1', @BuildDef) = 0
    BEGIN
        RAISERROR(
            'Patch 20 marker tidak ditemukan pada tenant Build. Patch 22 dihentikan.',
            16, 1
        );
    END;

    /* Idempotent. */
    IF CHARINDEX(N'SMK069-PRICE-POSITIVE-R1', @BuildDef) = 0
    BEGIN
        SET @BuildNew = @BuildDef;

        /* Confirm the tenant Build still projects PRICE from the Shipment View. */
        IF CHARINDEX(N'd.Price', @BuildNew) = 0
           AND CHARINDEX(N'd.[Price]', @BuildNew) = 0
        BEGIN
            RAISERROR(
                'Projection PRICE tidak ditemukan pada tenant Build. Patch 22 dihentikan agar tidak menebak schema.',
                16, 1
            );
        END;

        /*
           Insert immediately before the existing BUILD JSON section.
           This keeps all existing header/product guards and JSON projection intact.
        */
        SET @BuildJsonPos = CHARINDEX(N'-- BUILD JSON', @BuildNew);

        IF @BuildJsonPos = 0
        BEGIN
            RAISERROR(
                'Anchor "-- BUILD JSON" tidak ditemukan pada tenant Build. Patch 22 dihentikan.',
                16, 1
            );
        END;

        SET @BuildNew = STUFF(
            @BuildNew,
            @BuildJsonPos,
            0,
            N'/* SMK069-PRICE-POSITIVE-R1 */' + CHAR(13) + CHAR(10) +
            N'IF EXISTS' + CHAR(13) + CHAR(10) +
            N'(' + CHAR(13) + CHAR(10) +
            N'    SELECT 1' + CHAR(13) + CHAR(10) +
            N'    FROM dbo.SMK069_ShipmentAPI_mst AS pv' + CHAR(13) + CHAR(10) +
            N'    WHERE pv.site_ref = @Site' + CHAR(13) + CHAR(10) +
            N'      AND pv.DN_No = @DN_No' + CHAR(13) + CHAR(10) +
            N'      AND ISNULL(pv.Api_post, 0) = 0' + CHAR(13) + CHAR(10) +
            N'      AND ISNULL(pv.shipment_qty, 0) > 0' + CHAR(13) + CHAR(10) +
            N'      AND ISNULL(pv.Price, 0) <= 0' + CHAR(13) + CHAR(10) +
            N')' + CHAR(13) + CHAR(10) +
            N'BEGIN' + CHAR(13) + CHAR(10) +
            N'    SET @Infobar = N''Terdapat detail shipment dengan PRICE kosong atau <= 0. Shipment tidak dikirim ke POS.'';' + CHAR(13) + CHAR(10) +
            N'    RETURN 0;' + CHAR(13) + CHAR(10) +
            N'END;' + CHAR(13) + CHAR(10) +
            CHAR(13) + CHAR(10) +
            N'------------------------------------------------------------' + CHAR(13) + CHAR(10) +
            N'    '
        );

        /* Preserve exact current tenant signature/body. */
        SET @BuildNamePos = CHARINDEX(N'SMK069BuildShipmentJsonSp', @BuildNew);

        IF @BuildNamePos = 0
        BEGIN
            RAISERROR(
                'Nama SMK069BuildShipmentJsonSp tidak ditemukan di tenant definition.',
                16, 1
            );
        END;

        SET @BuildNew =
            N'CREATE OR ALTER PROCEDURE dbo.SMK069BuildShipmentJsonSp' +
            SUBSTRING(
                @BuildNew,
                @BuildNamePos + LEN(N'SMK069BuildShipmentJsonSp'),
                LEN(@BuildNew)
            );

        EXEC sys.sp_executesql @BuildNew;
    END;

    /* Post-patch assertions. */
    SET @BuildDef = OBJECT_DEFINITION(
        OBJECT_ID(N'dbo.SMK069BuildShipmentJsonSp', N'P')
    );

    IF CHARINDEX(
        N'SMK069-PRICE-POSITIVE-R1',
        ISNULL(@BuildDef, N'')
    ) = 0
    BEGIN
        RAISERROR(
            'PRICE positive guard marker tidak ditemukan setelah Patch 22.',
            16, 1
        );
    END;

    IF CHARINDEX(
        N'ISNULL(pv.Price, 0) <= 0',
        ISNULL(@BuildDef, N'')
    ) = 0
    BEGIN
        RAISERROR(
            'PRICE <= 0 guard tidak ditemukan setelah Patch 22.',
            16, 1
        );
    END;

    COMMIT TRANSACTION;

    PRINT 'OK - Patch 22 applied.';
    PRINT 'PRICE NULL / 0 / negative sekarang diblok sebelum Shipment API POST.';
    PRINT 'Shipment View tidak diubah.';
    PRINT 'BATCH dan EXPIRY_DATE tetap boleh NULL.';
    PRINT 'DOC_NO dan STORE_ORDER_NO non-blocking behavior tetap dipertahankan.';
    PRINT 'Patch ini tidak melakukan HTTP call / retry / TaskMan submit.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
