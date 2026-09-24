/* PROD migration artifact
   Source: database/patches/shipment/2026-09-09-smk069-14-allow-missing-doc-no.sql
   SyteLine Cloud Apply Database: one batch, NO GO.
*/
/* =============================================================================
   SMK069 - Shipment Patch 14 REVISION 2
   Allow missing DOC_NO without blocking send
   -----------------------------------------------------------------------------
   Date    : 2026-09-09
   Scope   : Shipment Outbound SyteLine -> POS API only
   Object  : dbo.SMK069BuildShipmentJsonSp

   REVISION 2 - WHY
   ----------------
   Revision 1 attempted an OPTIONAL View fallback by looking for the exact tenant
   projection:

       co.co_num AS doc_no

   The current tenant View does not contain that exact fragment, so Rev.1 stopped
   safely and rolled the transaction back. No tenant object was changed.

   The business requirement does NOT require the View to be changed. The actual
   requirement is simply:

       Shipment with missing DOC_NO must still be allowed to Build/Prepare.

   Therefore Revision 2 does NOT alter dbo.SMK069_ShipmentAPI_mst at all.
   It patches only the installed tenant dbo.SMK069BuildShipmentJsonSp and keeps
   all current tenant View logic intact.

   BUSINESS CHANGE
   ---------------
   Previous behavior:
       DOC_NO blank -> local validation RETURN -> no HTTP attempt

   New behavior:
       DOC_NO blank -> continue Build -> JSON contains "DOC_NO":""

   The POS API becomes the final authority on whether blank DOC_NO is accepted.

   SAFETY
   ------
   * Protection for MULTIPLE distinct nonblank DOC_NO values remains active.
   * Shipment View is NOT changed by this revision.
   * Current tenant Build body/signature are read from OBJECT_DEFINITION.
   * @DN_No must already be a String type; otherwise this patch aborts.
   * This patch does NOT Reset Retry and does NOT invoke HTTP.
   * This patch does NOT fix HTTP 404.
   * This patch does NOT fix SMK069CompleteShipmentSendSp nvarchar->bigint.
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
        @JsonDocPos    INT,
        @DnType        SYSNAME;

    SET @BuildObjectId = OBJECT_ID(N'dbo.SMK069BuildShipmentJsonSp', N'P');

    IF @BuildObjectId IS NULL
    BEGIN
        RAISERROR('dbo.SMK069BuildShipmentJsonSp tidak ditemukan.', 16, 1);
    END;

    /* -------------------------------------------------------------------------
       Guard the current prefixed-string DN contract (P96330/P96331/P96332).
       Never replace the tenant with the stale historical BIGINT Git body.
       ------------------------------------------------------------------------- */
    SELECT @DnType = TYPE_NAME(user_type_id)
    FROM sys.parameters
    WHERE object_id = @BuildObjectId
      AND parameter_id = 1
      AND name = N'@DN_No';

    IF LOWER(ISNULL(@DnType, N'')) NOT IN (N'nvarchar', N'varchar', N'nchar', N'char')
    BEGIN
        RAISERROR(
            'SMK069BuildShipmentJsonSp.@DN_No belum bertipe String. Patch 14 Rev.2 dihentikan untuk mencegah regresi DN P963xx.',
            16, 1
        );
    END;

    SET @BuildDef = OBJECT_DEFINITION(@BuildObjectId);

    IF @BuildDef IS NULL
    BEGIN
        RAISERROR('Definition dbo.SMK069BuildShipmentJsonSp tidak dapat dibaca.', 16, 1);
    END;

    /* -------------------------------------------------------------------------
       Idempotent: if Rev.2 marker already exists, do not modify again.
       ------------------------------------------------------------------------- */
    IF CHARINDEX(N'SMK069-DOC-NONBLOCKING-R2', @BuildDef) = 0
    BEGIN
        SET @BuildNew = @BuildDef;

        /* =====================================================================
           1. DocCount = 0 must no longer RETURN.

           Keep the existing multiple-DOC_NO guard untouched. Only remove the
           RETURN that follows the exact missing-DOC_NO message already observed
           at runtime for P96331.
           ===================================================================== */
        SET @MsgPos = CHARINDEX(
            N'tidak mempunyai DOC_NO/Customer Order.',
            @BuildNew
        );

        IF @MsgPos = 0
        BEGIN
            RAISERROR(
                'Guard message "tidak mempunyai DOC_NO/Customer Order." tidak ditemukan pada tenant Build. Patch 14 Rev.2 dihentikan.',
                16, 1
            );
        END;

        SET @ReturnPos = CHARINDEX(N'RETURN 0;', @BuildNew, @MsgPos);

        IF @ReturnPos = 0
        BEGIN
            RAISERROR(
                'RETURN setelah missing DOC_NO guard tidak ditemukan. Patch 14 Rev.2 dihentikan.',
                16, 1
            );
        END;

        SET @BuildNew = STUFF(
            @BuildNew,
            @ReturnPos,
            LEN(N'RETURN 0;'),
            N'/* SMK069-DOC-NONBLOCKING-R2: missing DOC_NO is warning only */'
        );

        /* =====================================================================
           2. Header @DocNo blank validation must also no longer RETURN.
           ===================================================================== */
        SET @MsgPos = CHARINDEX(N'DOC_NO kosong.', @BuildNew);

        IF @MsgPos > 0
        BEGIN
            SET @ReturnPos = CHARINDEX(N'RETURN 0;', @BuildNew, @MsgPos);

            IF @ReturnPos = 0
            BEGIN
                RAISERROR(
                    'RETURN setelah "DOC_NO kosong." tidak ditemukan. Patch 14 Rev.2 dihentikan.',
                    16, 1
                );
            END;

            SET @BuildNew = STUFF(
                @BuildNew,
                @ReturnPos,
                LEN(N'RETURN 0;'),
                N'/* SMK069-DOC-NONBLOCKING-R2: blank @DocNo is warning only */'
            );
        END;

        /* =====================================================================
           3. JSON must contain an empty STRING, not JSON null.
           ===================================================================== */
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
        ELSE IF CHARINDEX(
            N'ISNULL(@DocNo, N'''') AS [DOC_NO]',
            @BuildNew
        ) = 0
        BEGIN
            RAISERROR(
                'Projection JSON DOC_NO tenant tidak dikenali. Patch 14 Rev.2 dihentikan.',
                16, 1
            );
        END;

        /* =====================================================================
           4. Preserve exact current tenant signature/body and change only the
              guarded fragments above.
           ===================================================================== */
        SET @BuildNamePos = CHARINDEX(N'SMK069BuildShipmentJsonSp', @BuildNew);

        IF @BuildNamePos = 0
        BEGIN
            RAISERROR(
                'Nama SMK069BuildShipmentJsonSp tidak ditemukan di tenant definition.',
                16,
                1
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

    IF CHARINDEX(N'SMK069-DOC-NONBLOCKING-R2', ISNULL(@BuildDef, N'')) = 0
    BEGIN
        RAISERROR(
            'Build DOC_NO non-blocking Rev.2 marker tidak ditemukan setelah patch.',
            16,
            1
        );
    END;

    IF CHARINDEX(
        N'ISNULL(@DocNo, N'''') AS [DOC_NO]',
        ISNULL(@BuildDef, N'')
    ) = 0
    BEGIN
        RAISERROR(
            'Build JSON belum menormalisasi missing DOC_NO menjadi empty string.',
            16,
            1
        );
    END;

    COMMIT TRANSACTION;

    PRINT 'OK - Patch 14 Revision 2 applied.';
    PRINT 'Shipment View TIDAK diubah.';
    PRINT 'Missing DOC_NO tidak lagi menghentikan Build.';
    PRINT 'Jika DOC_NO tetap kosong, JSON berisi DOC_NO="".';
    PRINT 'Multiple distinct DOC_NO protection tetap aktif.';
    PRINT 'Patch ini TIDAK melakukan retry / HTTP call.';
    PRINT 'JANGAN Run Now sebelum HTTP 404 dan Complete nvarchar->bigint dibereskan.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
