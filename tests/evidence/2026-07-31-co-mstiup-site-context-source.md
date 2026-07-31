# Evidence — co_mstIup Site Context Source

Date: 31 July 2026
Tenant database: `LENSA_SL_CSI_BAK`

## Tenant-confirmed trigger assignments

The tenant source for `dbo.co_mstIup` shows:

```sql
SET @Site = dbo.GetSiteContext()
```

and inside the inserted-row cursor:

```sql
@OrigSite = ii.orig_site
```

The note-transfer branch is:

```sql
IF dbo.SkipRemoteUpdate() = 0
AND @Status <> 'H'
BEGIN
    IF @OrigSite <> @Site
    BEGIN
        EXEC @Severity = dbo.TransferNotesToSiteSp
            @ToSite = @OrigSite,
            @TableName = 'co',
            ...;
    END
    ELSE
    BEGIN
        EXEC @Severity = dbo.CopyNotesFromOrigSiteSp
            @CoNum = @CoNum,
            @CoType = @Type,
            @SourceSite = @Site,
            ...;
    END
END
```

## Confirmed interpretation

```text
@OrigSite source : inserted.orig_site
@Site source     : dbo.GetSiteContext()
```

The controlled insert supplies `orig_site = DEFAULT`, and both `dbo.parms_mst.site` and the staging `SiteRef` were confirmed as `DEFAULT`. The remote note-transfer branch nevertheless executed, so `dbo.GetSiteContext()` returned a value different from `DEFAULT` during trigger execution.

This invalidates the earlier assumption that the staging/site master value itself was wrong. The current issue is the SQL session context representation used by the direct stored procedure.

The previous raw `SET CONTEXT_INFO` assignment must not be treated as correct until the tenant implementation of `dbo.GetSiteContext()` is inspected.

## Next read-only step

```sql
SELECT
    OBJECT_DEFINITION(OBJECT_ID(N'dbo.GetSiteContext')) AS GetSiteContextDefinition;

SELECT
    dbo.GetSiteContext() AS CurrentGetSiteContext,
    CONTEXT_INFO() AS ContextInfoBinary,
    CONVERT(VARCHAR(128), CONTEXT_INFO()) AS ContextInfoText;
```

Do not modify `co_mstIup`, replication rules, or staging site values before the function contract is known.
