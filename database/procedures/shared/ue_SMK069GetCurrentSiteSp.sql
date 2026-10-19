/* =============================================================================
   SMK069 - Get Current Mongoose Site
   Date    : 2026-10-19
   Purpose : Return the active Mongoose site from SQL Server CONTEXT_INFO()
             for form-level SiteRef isolation.
   Contract: read-only; no data mutation; one OUTPUT parameter.
   ============================================================================= */
CREATE OR ALTER PROCEDURE dbo.ue_SMK069GetCurrentSiteSp
    @SiteRef dbo.SiteType OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @SiteRef =
        RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));

    RETURN 0;
END;
