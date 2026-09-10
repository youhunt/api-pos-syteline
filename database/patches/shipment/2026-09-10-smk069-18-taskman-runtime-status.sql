/* =============================================================================
   SMK069 - Shipment Patch 18 (WITHDRAWN / NO-OP)
   -----------------------------------------------------------------------------
   Date    : 2026-09-10
   Scope   : Shipment Outbound SyteLine -> POS API only

   STATUS
   ------
   WITHDRAWN after tenant Apply Database evidence proved dbo.ActiveBGTasks is
   not visible from this Cloud application database.

   ORIGINAL IDEA
   -------------
   Cross-check custom scheduler flags against dbo.ActiveBGTasks from SQL.

   TENANT EVIDENCE
   ---------------
   Apply Database returned:

       Patch 18 dihentikan: dbo.ActiveBGTasks tidak terlihat pada tenant ini.
       Jangan menebak runtime TaskMan source.

   CORRECT CLOUD DESIGN
   --------------------
   Runtime TaskMan truth must be loaded through the standard Mongoose IDO:

       MGCore.ActiveBGTasks

   and filtered for:

       TaskName = SMK069ShipmentScheduler

   The Shipment Scheduler form should use that IDO as a read-only secondary
   collection. Do not try to create an application-database view over a system
   table that is not exposed in this tenant.

   SAFETY
   ------
   This file intentionally performs NO database changes.
   It does NOT enable/disable scheduler, submit TaskMan, send HTTP, or touch
   retries.

   See:
       docs/shipment/38-runtime-truth-via-mgcore-activebgtasks.md
   ============================================================================= */

SET NOCOUNT ON;

PRINT 'Patch 18 is WITHDRAWN for this Cloud tenant.';
PRINT 'No database changes were made.';
PRINT 'Use MGCore.ActiveBGTasks directly from the Mongoose form for actual TaskMan runtime status.';
