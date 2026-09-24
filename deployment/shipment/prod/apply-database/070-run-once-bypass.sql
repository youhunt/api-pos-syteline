/* PROD migration artifact
   Source: database/patches/shipment/2026-09-10-smk069-19-run-once-bypass-scheduler-switches.sql
   SyteLine Cloud Apply Database: one batch, NO GO.
*/
/* =============================================================================
   SMK069 - Shipment Patch 19
   Allow manual RUN ONCE while recurring scheduler is OFF
   -----------------------------------------------------------------------------
   Date    : 2026-09-10
   Scope   : Shipment Outbound SyteLine -> POS API only

   USER INTENT
   -----------
   RUN ONCE is a manual one-time execution and must NOT require the recurring
   scheduler to be started first.

   Desired behavior:

       START SCHEDULER
         -> recurring / automatic execution only

       RUN ONCE
         -> allowed when Master Scheduler is OFF
         -> allowed when Business Schedule is DISABLED
         -> submits one TaskMan invocation only
         -> does not permanently enable recurring scheduler

   WHY TWO PROCEDURES MUST CHANGE
   ------------------------------
   Current runtime contract has two independent recurring-scheduler gates:

   1) SMK069RequestShipmentRunNowSp rejects when SchedulerEnabled = 0.
   2) SMK069ClaimDueShipmentScheduleSp returns no work when SchedulerEnabled = 0
      and normally only claims IsEnabled = 1 schedule rows.

   Removing only the form popup is therefore insufficient.

   PATCH STRATEGY
   --------------
   Tenant-preserving OBJECT_DEFINITION surgery with strong guards:

   A. RequestShipmentRunNow:
      keep the master-OFF message for audit, but remove only the following
      RETURN 16 so RunRequested=1 can still be set.

   B. ClaimDueShipmentSchedule:
      remove only the early RETURN 0 after the known master-OFF message;
      then tighten candidate selection so:

         Master ON  -> automatic due schedule OR RunRequested=1
         Master OFF -> ONLY RunRequested=1

      A manual RunRequested row may be claimed even when IsEnabled=0.

   SAFETY
   ------
   * Does NOT enable SchedulerEnabled.
   * Does NOT enable IsEnabled.
   * Does NOT send HTTP by itself.
   * Does NOT submit TaskMan by itself.
   * Does NOT reset retry counters.
   * Does NOT touch endpoint/credentials/Build/Prepare/Complete.
   * One executable Apply Database batch; NO GO.
   ============================================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @RequestObjectId INT = OBJECT_ID(N'dbo.SMK069RequestShipmentRunNowSp', N'P');
    DECLARE @ClaimObjectId   INT = OBJECT_ID(N'dbo.SMK069ClaimDueShipmentScheduleSp', N'P');

    IF @RequestObjectId IS NULL
        RAISERROR('Patch 19: dbo.SMK069RequestShipmentRunNowSp tidak ditemukan.', 16, 1);

    IF @ClaimObjectId IS NULL
        RAISERROR('Patch 19: dbo.SMK069ClaimDueShipmentScheduleSp tidak ditemukan.', 16, 1);

    DECLARE @RequestDef NVARCHAR(MAX) = OBJECT_DEFINITION(@RequestObjectId);
    DECLARE @ClaimDef   NVARCHAR(MAX) = OBJECT_DEFINITION(@ClaimObjectId);

    IF @RequestDef IS NULL OR @ClaimDef IS NULL
        RAISERROR('Patch 19: source procedure tenant tidak dapat dibaca.', 16, 1);

    /* -------------------------------------------------------------------------
       A. REQUEST RUN NOW - remove only master-OFF hard return
       ------------------------------------------------------------------------- */
    IF CHARINDEX(N'SMK069-RUNONCE-BYPASS-MASTER-R1', @RequestDef) = 0
    BEGIN
        DECLARE @RequestMsg NVARCHAR(300) =
            N'Master Shipment Scheduler masih OFF. Aktifkan master switch lebih dulu.';
        DECLARE @RequestMsgPos INT = CHARINDEX(@RequestMsg, @RequestDef);
        DECLARE @RequestReturnPos INT;

        IF @RequestMsgPos = 0
            RAISERROR('Patch 19: known master-OFF guard pada RequestShipmentRunNow tidak ditemukan. Tenant drift; patch dihentikan.', 16, 1);

        SET @RequestReturnPos = CHARINDEX(N'RETURN 16;', @RequestDef, @RequestMsgPos);

        IF @RequestReturnPos = 0 OR @RequestReturnPos - @RequestMsgPos > 400
            RAISERROR('Patch 19: RETURN 16 target pada RequestShipmentRunNow tidak aman ditemukan.', 16, 1);

        SET @RequestDef = STUFF(
            @RequestDef,
            @RequestReturnPos,
            LEN(N'RETURN 16;'),
            N'/* SMK069-RUNONCE-BYPASS-MASTER-R1 */'
        );

        SET @RequestDef = REPLACE(
            @RequestDef,
            N'CREATE PROCEDURE',
            N'CREATE OR ALTER PROCEDURE'
        );

        IF LEFT(LTRIM(@RequestDef), 16) = N'CREATE   PROCEDURE'
            SET @RequestDef = STUFF(@RequestDef, CHARINDEX(N'CREATE', @RequestDef), LEN(N'CREATE   PROCEDURE'), N'CREATE OR ALTER PROCEDURE');

        EXEC sys.sp_executesql @RequestDef;
    END;

    /* -------------------------------------------------------------------------
       B. CLAIM DUE SCHEDULE - allow requested manual row while master is OFF
       ------------------------------------------------------------------------- */
    SET @ClaimDef = OBJECT_DEFINITION(@ClaimObjectId);

    IF CHARINDEX(N'SMK069-RUNONCE-CLAIM-MANUAL-R1', @ClaimDef) = 0
    BEGIN
        DECLARE @ClaimMsg NVARCHAR(300) =
            N'Master Shipment Scheduler OFF; tidak ada schedule yang diklaim.';
        DECLARE @ClaimMsgPos INT = CHARINDEX(@ClaimMsg, @ClaimDef);
        DECLARE @ClaimReturnPos INT;
        DECLARE @EnabledPos INT;

        IF @ClaimMsgPos = 0
            RAISERROR('Patch 19: known master-OFF guard pada ClaimDueShipmentSchedule tidak ditemukan. Tenant drift; patch dihentikan.', 16, 1);

        SET @ClaimReturnPos = CHARINDEX(N'RETURN 0;', @ClaimDef, @ClaimMsgPos);

        IF @ClaimReturnPos = 0 OR @ClaimReturnPos - @ClaimMsgPos > 400
            RAISERROR('Patch 19: RETURN 0 target pada ClaimDueShipmentSchedule tidak aman ditemukan.', 16, 1);

        SET @ClaimDef = STUFF(
            @ClaimDef,
            @ClaimReturnPos,
            LEN(N'RETURN 0;'),
            N'/* SMK069-RUNONCE-CLAIM-MANUAL-R1: continue; candidate filter below allows only RunRequested when master OFF */'
        );

        /* Find the schedule candidate predicate after the master guard. */
        SET @EnabledPos = CHARINDEX(N'AND IsEnabled = 1', @ClaimDef, @ClaimMsgPos);

        IF @EnabledPos = 0
            RAISERROR('Patch 19: IsEnabled candidate predicate pada ClaimDueShipmentSchedule tidak ditemukan.', 16, 1);

        SET @ClaimDef = STUFF(
            @ClaimDef,
            @EnabledPos,
            LEN(N'AND IsEnabled = 1'),
            N'AND (IsEnabled = 1 OR RunRequested = 1)' + CHAR(13) + CHAR(10) +
            N'      AND (ISNULL(@MasterEnabled, 0) = 1 OR RunRequested = 1)'
        );

        SET @ClaimDef = REPLACE(
            @ClaimDef,
            N'CREATE PROCEDURE',
            N'CREATE OR ALTER PROCEDURE'
        );

        IF LEFT(LTRIM(@ClaimDef), 16) = N'CREATE   PROCEDURE'
            SET @ClaimDef = STUFF(@ClaimDef, CHARINDEX(N'CREATE', @ClaimDef), LEN(N'CREATE   PROCEDURE'), N'CREATE OR ALTER PROCEDURE');

        EXEC sys.sp_executesql @ClaimDef;
    END;

    /* -------------------------------------------------------------------------
       POST ASSERTIONS
       ------------------------------------------------------------------------- */
    SET @RequestDef = OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069RequestShipmentRunNowSp', N'P'));
    SET @ClaimDef   = OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ClaimDueShipmentScheduleSp', N'P'));

    IF CHARINDEX(N'SMK069-RUNONCE-BYPASS-MASTER-R1', ISNULL(@RequestDef, N'')) = 0
        RAISERROR('Patch 19 post-assertion gagal: Request Run Once marker tidak ada.', 16, 1);

    IF CHARINDEX(N'SMK069-RUNONCE-CLAIM-MANUAL-R1', ISNULL(@ClaimDef, N'')) = 0
        RAISERROR('Patch 19 post-assertion gagal: Claim manual marker tidak ada.', 16, 1);

    IF CHARINDEX(N'AND (IsEnabled = 1 OR RunRequested = 1)', ISNULL(@ClaimDef, N'')) = 0
        RAISERROR('Patch 19 post-assertion gagal: manual disabled-schedule predicate tidak ada.', 16, 1);

    IF CHARINDEX(N'AND (ISNULL(@MasterEnabled, 0) = 1 OR RunRequested = 1)', ISNULL(@ClaimDef, N'')) = 0
        RAISERROR('Patch 19 post-assertion gagal: manual master-bypass predicate tidak ada.', 16, 1);

    COMMIT TRANSACTION;

    PRINT 'OK - Patch 19 applied.';
    PRINT 'RUN ONCE sekarang boleh saat Master Scheduler OFF.';
    PRINT 'RUN ONCE sekarang boleh saat Business Schedule DISABLED.';
    PRINT 'Master OFF hanya boleh claim row dengan RunRequested=1; automatic due schedule tetap diblok.';
    PRINT 'Patch ini TIDAK enable scheduler dan TIDAK melakukan HTTP/TaskMan submit.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
