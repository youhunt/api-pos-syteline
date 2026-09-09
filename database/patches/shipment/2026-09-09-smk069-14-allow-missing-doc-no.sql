/* =============================================================================
   SMK069 - Shipment Patch 14 - Allow missing DOC_NO without blocking send
   -----------------------------------------------------------------------------
   Date    : 2026-09-09
   Scope   : Shipment Outbound SyteLine -> POS API only
   Objects : dbo.SMK069_ShipmentAPI_mst
             dbo.SMK069BuildShipmentJsonSp

   BUSINESS CHANGE
   ---------------
   A Shipment must no longer stop locally only because DOC_NO is blank.

   Preferred DOC_NO source order becomes:
       1. co_mst.co_num
       2. coitem_mst.co_num
       3. shipment_line_mst.ref_num
       4. blank string if all three are absent

   If all real references are absent, JSON is still built with:
       "DOC_NO": ""

   POS API then decides whether blank DOC_NO is acceptable. This intentionally
   prevents SyteLine Build/Prepare from blocking the attempt before HTTP.

   IMPORTANT SAFETY
   ----------------
   * Protection for MULTIPLE distinct DOC_NO values remains unchanged.
   * This patch does NOT Reset Retry and does NOT invoke HTTP.
   * This patch does NOT fix the current HTTP 404 endpoint issue.
   * This patch does NOT fix SMK069CompleteShipmentSendSp nvarchar->bigint.
   * Do not retry P96330/P96332 until those two root causes are fixed.
   * P96331 may only be retried after this patch AND the common transport/
     Complete root causes are resolved.

   SOURCE-CONTROL SAFETY
   ---------------------
   The repo standalone View/Build files are stale versus the tenant string-DN
   runtime. Therefore this patch reads OBJECT_DEFINITION and edits only guarded
   fragments in the installed tenant modules. It aborts if expected markers are
   not found instead of replacing the tenant with an older full definition.

   Designed for Infor Apply Database: ONE executable batch, NO GO.
   ============================================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    /* =========================================================================
       1. VIEW: prefer a real Shipment/CO reference before declaring DOC_NO blank
       ========================================================================= */
    DECLARE
        @ViewObjectId INT,
        @ViewDef      NVARCHAR(MAX),
        @ViewNew      NVARCHAR(MAX),
        @ViewNamePos  INT,
        @ViewDocPos   INT;

    SET @ViewObjectId = OBJECT_ID(N'dbo.SMK069_ShipmentAPI_mst', N'V');

    IF @ViewObjectId IS NULL
    BEGIN
        RAISERROR('dbo.SMK069_ShipmentAPI_mst tidak ditemukan.', 16, 1);
    END;

    SET @ViewDef = OBJECT_DEFINITION(@ViewObjectId);

    IF @ViewDef IS NULL
    BEGIN
        RAISERROR('Definition dbo.SMK069_ShipmentAPI_mst tidak dapat dibaca.', 16, 1);
    END;

    IF CHARINDEX(N'SMK069-DOC-FALLBACK', @ViewDef) = 0
    BEGIN
        /* Deliberately require the exact old projection fragment. If the tenant
           differs, stop and capture its definition rather than guessing. */
        SET @ViewDocPos = CHARINDEX(N'co.co_num AS doc_no', @ViewDef);

        IF @ViewDocPos = 0
        BEGIN
            RAISERROR(
                'Projection "co.co_num AS doc_no" tidak ditemukan pada tenant View. Patch 14 dihentikan; jangan replace full View dari Git.',
                16, 1
            );
        END;

        SET @ViewNew = STUFF(
            @ViewDef,
            @ViewDocPos,
            LEN(N'co.co_num AS doc_no'),
            N'COALESCE(' +
            N'NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(50), co.co_num))), N''''),' +
            N'NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(50), coi.co_num))), N''''),' +
            N'NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(50), shl.ref_num))), N'''')' +
            N') AS doc_no /* SMK069-DOC-FALLBACK */'
        );

        /* Preserve everything after the actual tenant object name, including
           the current prefixed DN and numeric-UOM logic. */
        SET @ViewNamePos = CHARINDEX(N'SMK069_ShipmentAPI_mst', @ViewNew);

        IF @ViewNamePos = 0
        BEGIN
            RAISERROR('Nama View tidak ditemukan di tenant definition.', 16, 1);
        END;

        SET @ViewNew =
            N'CREATE OR ALTER VIEW dbo.SMK069_ShipmentAPI_mst' +
            SUBSTRING(
                @ViewNew,
                @ViewNamePos + LEN(N'SMK069_ShipmentAPI_mst'),
                LEN(@ViewNew)
            );

        EXEC sys.sp_executesql @ViewNew;
    END;

    /* =========================================================================
       2. BUILD: missing DOC_NO becomes non-blocking
       ========================================================================= */
    DECLARE
        @BuildObjectId INT,
        @BuildDef      NVARCHAR(MAX),
        @BuildNew      NVARCHAR(MAX),
        @BuildNamePos  INT,
        @MsgPos        INT,
        @ReturnPos     INT,
        @JsonDocPos    INT,
        @DnType        SYSNAME;

    SET @BuildObjectId = OBJECT_ID(N'dbo.SMK069BuildShipmentJsonSp', N'P');

    IF @BuildObjectId IS NULL
    BEGIN
        RAISERROR('dbo.SMK069BuildShipmentJsonSp tidak ditemukan.', 16, 1);
    END;

    SELECT @DnType = TYPE_NAME(user_type_id)
    FROM sys.parameters
    WHERE object_id = @BuildObjectId
      AND parameter_id = 1
      AND name = N'@DN_No';

    /* Protect the tenant from accidentally reapplying the stale Git BIGINT body. */
    IF LOWER(ISNULL(@DnType, N'')) NOT IN (N'nvarchar', N'varchar', N'nchar', N'char')
    BEGIN
        RAISERROR(
            'SMK069BuildShipmentJsonSp.@DN_No belum bertipe String. Patch 14 dihentikan untuk mencegah regresi DN P963xx.',
            16, 1
        );
    END;

    SET @BuildDef = OBJECT_DEFINITION(@BuildObjectId);

    IF @BuildDef IS NULL
    BEGIN
        RAISERROR('Definition dbo.SMK069BuildShipmentJsonSp tidak dapat dibaca.', 16, 1);
    END;

    IF CHARINDEX(N'SMK069-DOC-NONBLOCKING', @BuildDef) = 0
    BEGIN
        SET @BuildNew = @BuildDef;

        /* 2a. Do not return when distinct nonblank DOC_NO count is zero. */
        SET @MsgPos = CHARINDEX(N'tidak mempunyai DOC_NO/Customer Order.', @BuildNew);

        IF @MsgPos = 0
        BEGIN
            RAISERROR(
                'Guard message "tidak mempunyai DOC_NO/Customer Order." tidak ditemukan. Patch 14 dihentikan.',
                16, 1
            );
        END;

        SET @ReturnPos = CHARINDEX(N'RETURN 0;', @BuildNew, @MsgPos);

        IF @ReturnPos = 0
        BEGIN
            RAISERROR('RETURN setelah missing DOC_NO guard tidak ditemukan.', 16, 1);
        END;

        SET @BuildNew = STUFF(
            @BuildNew,
            @ReturnPos,
            LEN(N'RETURN 0;'),
            N'/* SMK069-DOC-NONBLOCKING */ SET @Infobar = @Infobar;'
        );

        /* 2b. Do not return during header validation when @DocNo is blank. */
        SET @MsgPos = CHARINDEX(N'DOC_NO kosong.', @BuildNew);

        IF @MsgPos = 0
        BEGIN
            RAISERROR('Guard message "DOC_NO kosong." tidak ditemukan. Patch 14 dihentikan.', 16, 1);
        END;

        SET @ReturnPos = CHARINDEX(N'RETURN 0;', @BuildNew, @MsgPos);

        IF @ReturnPos = 0
        BEGIN
            RAISERROR('RETURN setelah DOC_NO kosong guard tidak ditemukan.', 16, 1);
        END;

        SET @BuildNew = STUFF(
            @BuildNew,
            @ReturnPos,
            LEN(N'RETURN 0;'),
            N'/* SMK069-DOC-NONBLOCKING */ SET @Infobar = @Infobar;'
        );

        /* 2c. Keep the field a JSON string instead of JSON null. */
        SET @JsonDocPos = CHARINDEX(N'@DocNo AS [DOC_NO]', @BuildNew);

        IF @JsonDocPos > 0
        BEGIN
            SET @BuildNew = STUFF(
                @BuildNew,
                @JsonDocPos,
                LEN(N'@DocNo AS [DOC_NO]'),
                N'ISNULL(@DocNo, N'''') AS [DOC_NO]'
            );
        END
        ELSE IF CHARINDEX(N'ISNULL(@DocNo, N'''') AS [DOC_NO]', @BuildNew) = 0
        BEGIN
            RAISERROR('Projection JSON DOC_NO tidak dikenali. Patch 14 dihentikan.', 16, 1);
        END;

        /* Preserve current tenant procedure body and signature. */
        SET @BuildNamePos = CHARINDEX(N'SMK069BuildShipmentJsonSp', @BuildNew);

        IF @BuildNamePos = 0
        BEGIN
            RAISERROR('Nama Build procedure tidak ditemukan di tenant definition.', 16, 1);
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

    /* =========================================================================
       3. POST-PATCH ASSERTIONS
       ========================================================================= */
    IF CHARINDEX(
        N'SMK069-DOC-FALLBACK',
        ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069_ShipmentAPI_mst', N'V')), N'')
    ) = 0
    BEGIN
        RAISERROR('View DOC_NO fallback marker tidak ditemukan setelah patch.', 16, 1);
    END;

    IF CHARINDEX(
        N'SMK069-DOC-NONBLOCKING',
        ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069BuildShipmentJsonSp', N'P')), N'')
    ) = 0
    BEGIN
        RAISERROR('Build DOC_NO non-blocking marker tidak ditemukan setelah patch.', 16, 1);
    END;

    IF CHARINDEX(
        N'ISNULL(@DocNo, N'''') AS [DOC_NO]',
        ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069BuildShipmentJsonSp', N'P')), N'')
    ) = 0
    BEGIN
        RAISERROR('Build JSON belum menormalisasi missing DOC_NO menjadi empty string.', 16, 1);
    END;

    COMMIT TRANSACTION;

    PRINT 'OK - Patch 14 applied.';
    PRINT 'DOC_NO sekarang fallback co_mst -> coitem -> shipment_line.ref_num.';
    PRINT 'Jika tetap kosong, Build tetap menghasilkan JSON dengan DOC_NO="".';
    PRINT 'Multiple DOC_NO protection tetap aktif.';
    PRINT 'JANGAN retry sebelum HTTP 404 dan Complete nvarchar->bigint diperbaiki.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
