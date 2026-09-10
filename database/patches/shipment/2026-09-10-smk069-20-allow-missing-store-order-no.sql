/* =============================================================================
   SMK069 - Shipment Patch 20
   Allow missing STORE_ORDER_NO without blocking send
   -----------------------------------------------------------------------------
   Date    : 2026-09-10
   Scope   : Shipment Outbound SyteLine -> POS API only
   Object  : dbo.SMK069BuildShipmentJsonSp

   TENANT EVIDENCE
   ---------------
   Controlled P96331 attempt reached the current tenant Build and stopped with:

       STORE_ORDER_NO kosong.

   Current tenant source around the guard was captured as:

       IF NULLIF(LTRIM(RTRIM(ISNULL(@StoreOrderNo, ''))), '') IS NULL
       BEGIN
           SET @Infobar = 'STORE_ORDER_NO kosong.';
           RETURN 0;
       END;

   P96331 had already passed the missing-DOC_NO gate fixed by Patch 14 Rev.2.
   This proves STORE_ORDER_NO is a separate remaining local blocker for the
   agreed business rule that Shipment may proceed without Customer Order data.

   BUSINESS CHANGE
   ---------------
   Previous behavior:
       STORE_ORDER_NO blank -> local validation RETURN -> no HTTP attempt

   New behavior:
       STORE_ORDER_NO blank -> continue Build -> JSON contains
                               "STORE_ORDER_NO":""

   POS remains the final authority on whether blank STORE_ORDER_NO is accepted.

   SAFETY
   ------
   * Current tenant Build body/signature are read from OBJECT_DEFINITION.
   * @DN_No must already be a String type; otherwise this patch aborts.
   * DOC_NO Patch 14 Rev.2 marker must already exist; otherwise this patch aborts.
   * Shipment View is NOT changed.
   * This patch does NOT Reset Retry.
   * This patch does NOT submit TaskMan.
   * This patch does NOT invoke HTTP.
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
        @MsgPos        INT,
        @ReturnPos     INT,
        @JsonPos       INT,
        @DnType        SYSNAME;

    SET @BuildObjectId = OBJECT_ID(N'dbo.SMK069BuildShipmentJsonSp', N'P');

    IF @BuildObjectId IS NULL
    BEGIN
        RAISERROR('dbo.SMK069BuildShipmentJsonSp tidak ditemukan.', 16, 1);
    END;

    /* Preserve the current prefixed-string DN contract. */
    SELECT @DnType = TYPE_NAME(user_type_id)
    FROM sys.parameters
    WHERE object_id = @BuildObjectId
      AND parameter_id = 1
      AND name = N'@DN_No';

    IF LOWER(ISNULL(@DnType, N'')) NOT IN (N'nvarchar', N'varchar', N'nchar', N'char')
    BEGIN
        RAISERROR(
            'SMK069BuildShipmentJsonSp.@DN_No bukan String. Patch 20 dihentikan untuk mencegah regresi DN P963xx/R975xx.',
            16, 1
        );
    END;

    SET @BuildDef = OBJECT_DEFINITION(@BuildObjectId);

    IF @BuildDef IS NULL
    BEGIN
        RAISERROR('Definition dbo.SMK069BuildShipmentJsonSp tidak dapat dibaca.', 16, 1);
    END;

    /* Patch 20 depends on the already verified DOC_NO non-blocking runtime. */
    IF CHARINDEX(N'SMK069-DOC-NONBLOCKING-R2', @BuildDef) = 0
    BEGIN
        RAISERROR(
            'Patch 14 Rev.2 marker tidak ditemukan pada tenant Build. Patch 20 dihentikan.',
            16, 1
        );
    END;

    /* Idempotent. */
    IF CHARINDEX(N'SMK069-STORE-ORDER-NONBLOCKING-R1', @BuildDef) = 0
    BEGIN
        SET @BuildNew = @BuildDef;

        /* =====================================================================
           1. Exact observed STORE_ORDER_NO blank guard becomes warning-only.
           ===================================================================== */
        SET @MsgPos = CHARINDEX(N'STORE_ORDER_NO kosong.', @BuildNew);

        IF @MsgPos = 0
        BEGIN
            RAISERROR(
                'Guard message "STORE_ORDER_NO kosong." tidak ditemukan pada tenant Build. Patch 20 dihentikan.',
                16, 1
            );
        END;

        SET @ReturnPos = CHARINDEX(N'RETURN 0;', @BuildNew, @MsgPos);

        IF @ReturnPos = 0
        BEGIN
            RAISERROR(
                'RETURN setelah STORE_ORDER_NO guard tidak ditemukan. Patch 20 dihentikan.',
                16, 1
            );
        END;

        SET @BuildNew = STUFF(
            @BuildNew,
            @ReturnPos,
            LEN(N'RETURN 0;'),
            N'/* SMK069-STORE-ORDER-NONBLOCKING-R1: blank STORE_ORDER_NO is warning only */'
        );

        /* =====================================================================
           2. JSON must contain an empty STRING, not JSON null.
           ===================================================================== */
        SET @JsonPos = CHARINDEX(N'@StoreOrderNo AS [STORE_ORDER_NO]', @BuildNew);

        IF @JsonPos > 0
        BEGIN
            SET @BuildNew = STUFF(
                @BuildNew,
                @JsonPos,
                LEN(N'@StoreOrderNo AS [STORE_ORDER_NO]'),
                N'ISNULL(@StoreOrderNo, N'''') AS [STORE_ORDER_NO]'
            );
        END
        ELSE IF CHARINDEX(
            N'ISNULL(@StoreOrderNo, N'''') AS [STORE_ORDER_NO]',
            @BuildNew
        ) = 0
        BEGIN
            RAISERROR(
                'Projection JSON STORE_ORDER_NO tenant tidak dikenali. Patch 20 dihentikan.',
                16, 1
            );
        END;

        /* =====================================================================
           3. Preserve exact current tenant signature/body and change only the
              guarded fragments above.
           ===================================================================== */
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

    /* -------------------------------------------------------------------------
       Post-patch assertions.
       ------------------------------------------------------------------------- */
    SET @BuildDef = OBJECT_DEFINITION(
        OBJECT_ID(N'dbo.SMK069BuildShipmentJsonSp', N'P')
    );

    IF CHARINDEX(
        N'SMK069-STORE-ORDER-NONBLOCKING-R1',
        ISNULL(@BuildDef, N'')
    ) = 0
    BEGIN
        RAISERROR(
            'STORE_ORDER_NO non-blocking marker tidak ditemukan setelah patch.',
            16, 1
        );
    END;

    IF CHARINDEX(
        N'ISNULL(@StoreOrderNo, N'''') AS [STORE_ORDER_NO]',
        ISNULL(@BuildDef, N'')
    ) = 0
    BEGIN
        RAISERROR(
            'Build JSON belum menormalisasi missing STORE_ORDER_NO menjadi empty string.',
            16, 1
        );
    END;

    COMMIT TRANSACTION;

    PRINT 'OK - Patch 20 applied.';
    PRINT 'Shipment View TIDAK diubah.';
    PRINT 'Missing STORE_ORDER_NO tidak lagi menghentikan Build.';
    PRINT 'Jika STORE_ORDER_NO kosong, JSON berisi STORE_ORDER_NO="".';
    PRINT 'DOC_NO non-blocking Patch 14 Rev.2 tetap dipertahankan.';
    PRINT 'Patch ini TIDAK melakukan retry / TaskMan submit / HTTP call.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
