/* =============================================================================
   SMK069 - Patch 11 - Fix Prepare Shipment DN_No from BIGINT to NVARCHAR(40)
   -----------------------------------------------------------------------------
   Date    : 2026-09-09
   Object  : dbo.SMK069PrepareShipmentSendSp
   Purpose : Align Prepare Shipment with the current prefixed DN contract
             (for example P96330 / P96331).

   TENANT EVIDENCE
   ---------------
   sys.parameters returned:

       SMK069PrepareShipmentSendSp  @DN_No  bigint
       SMK069BuildShipmentJsonSp    @DN_No  nvarchar

   Runtime therefore failed before HTTP with:

       IDOValueType.GetValue: failed to parse normalized string [P96330],
       Type = Int64

   IMPORTANT
   ---------
   The repository does not own the current full tenant definition of
   SMK069PrepareShipmentSendSp. This patch deliberately preserves the installed
   tenant body and changes ONLY the first parameter declaration to NVARCHAR(40).

   Designed for Infor Apply Database: one executable batch, no GO separator.
   ============================================================================= */

SET NOCOUNT ON;

DECLARE
    @ObjectId   INT,
    @Definition NVARCHAR(MAX),
    @NamePos    INT,
    @DnPos      INT,
    @CommaPos   INT,
    @Between    NVARCHAR(MAX),
    @Tail       NVARCHAR(MAX),
    @NewDef     NVARCHAR(MAX),
    @CurrentType SYSNAME;

SET @ObjectId = OBJECT_ID(N'dbo.SMK069PrepareShipmentSendSp', N'P');

IF @ObjectId IS NULL
BEGIN
    RAISERROR('dbo.SMK069PrepareShipmentSendSp tidak ditemukan.', 16, 1);
    RETURN;
END;

SELECT @CurrentType = TYPE_NAME(user_type_id)
FROM sys.parameters
WHERE object_id = @ObjectId
  AND parameter_id = 1
  AND name = N'@DN_No';

IF @CurrentType IS NULL
BEGIN
    RAISERROR('Parameter pertama @DN_No pada dbo.SMK069PrepareShipmentSendSp tidak ditemukan.', 16, 1);
    RETURN;
END;

IF LOWER(@CurrentType) IN (N'nvarchar', N'varchar', N'nchar', N'char')
BEGIN
    PRINT 'SMK069PrepareShipmentSendSp.@DN_No sudah string. Tidak ada perubahan.';
    RETURN;
END;

IF LOWER(@CurrentType) <> N'bigint'
BEGIN
    RAISERROR('SMK069PrepareShipmentSendSp.@DN_No bukan BIGINT dan bukan string. Patch dihentikan untuk keamanan.', 16, 1);
    RETURN;
END;

SET @Definition = OBJECT_DEFINITION(@ObjectId);

IF @Definition IS NULL
BEGIN
    RAISERROR('Definition dbo.SMK069PrepareShipmentSendSp tidak dapat dibaca.', 16, 1);
    RETURN;
END;

/* Rebuild only the CREATE/ALTER prefix and the first parameter declaration.
   Everything from the comma after @DN_No onward is preserved byte-for-byte. */
SET @NamePos = CHARINDEX(N'SMK069PrepareShipmentSendSp', @Definition);

IF @NamePos = 0
BEGIN
    RAISERROR('Nama procedure tidak ditemukan di source definition.', 16, 1);
    RETURN;
END;

SET @DnPos = CHARINDEX(N'@DN_No', @Definition, @NamePos + LEN(N'SMK069PrepareShipmentSendSp'));

IF @DnPos = 0
BEGIN
    RAISERROR('@DN_No tidak ditemukan di source definition.', 16, 1);
    RETURN;
END;

SET @CommaPos = CHARINDEX(N',', @Definition, @DnPos);

IF @CommaPos = 0
BEGIN
    RAISERROR('Batas parameter @DN_No tidak ditemukan di source definition.', 16, 1);
    RETURN;
END;

SET @Between = SUBSTRING(
    @Definition,
    @NamePos + LEN(N'SMK069PrepareShipmentSendSp'),
    @DnPos - (@NamePos + LEN(N'SMK069PrepareShipmentSendSp'))
);

SET @Tail = SUBSTRING(
    @Definition,
    @CommaPos,
    LEN(@Definition) - @CommaPos + 1
);

SET @NewDef =
    N'CREATE OR ALTER PROCEDURE dbo.SMK069PrepareShipmentSendSp' +
    @Between +
    N'@DN_No NVARCHAR(40)' +
    @Tail;

EXEC sys.sp_executesql @NewDef;

/* Fail loudly if the signature did not actually change. */
SELECT @CurrentType = TYPE_NAME(user_type_id)
FROM sys.parameters
WHERE object_id = OBJECT_ID(N'dbo.SMK069PrepareShipmentSendSp', N'P')
  AND parameter_id = 1
  AND name = N'@DN_No';

IF LOWER(ISNULL(@CurrentType, N'')) <> N'nvarchar'
BEGIN
    RAISERROR('Patch selesai dieksekusi tetapi @DN_No belum NVARCHAR. Jangan lanjut UAT.', 16, 1);
    RETURN;
END;

PRINT 'OK - dbo.SMK069PrepareShipmentSendSp.@DN_No sekarang NVARCHAR(40).';
