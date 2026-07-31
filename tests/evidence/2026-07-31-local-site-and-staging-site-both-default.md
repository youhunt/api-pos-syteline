# Evidence — Local Site and Staging Site Both DEFAULT

Date: 31 July 2026
Tenant database: `LENSA_SL_CSI_BAK`

## Tenant result

The user queried both the local application parameter table and the selected staging order.

```sql
SELECT LTRIM(RTRIM(site)) AS LocalSite
FROM dbo.parms_mst;

SELECT DISTINCT
    LTRIM(RTRIM(SiteRef)) AS StagingSite,
    LTRIM(RTRIM(co_num)) AS SourceCoNum
FROM dbo.ue_SMK069_temp_sales_mst
WHERE LTRIM(RTRIM(co_num)) = N'TEST000001';
```

Returned values:

```text
LocalSite   : Default
StagingSite : DEFAULT
SourceCoNum : TEST000001
```

## Interpretation

This disproves the prior hypothesis that the replication error was caused by a mismatch between staging `SiteRef` and `dbo.parms_mst.site`.

The trigger branch in `dbo.co_mstIup` is still confirmed:

```sql
IF dbo.SkipRemoteUpdate() = 0
AND @Status != 'H'
BEGIN
    IF @OrigSite != @Site
    BEGIN
        EXEC @Severity = dbo.TransferNotesToSiteSp
            @ToSite = @OrigSite,
            ...;
    END;
END;
```

Because both visible persisted values are `DEFAULT`, the next step is to inspect the actual assignments of trigger variables `@Site` and `@OrigSite`. One of them may be derived from a session function, view, configuration context, or inserted-row source other than the persisted values already queried.

## Next read-only step

Extract the assignment blocks for `@Site` and `@OrigSite` from `dbo.co_mstIup`:

```sql
DECLARE @Definition NVARCHAR(MAX);

SELECT @Definition = sm.definition
FROM sys.sql_modules AS sm
WHERE sm.object_id = OBJECT_ID(N'dbo.co_mstIup');

SELECT
    CHARINDEX(N'@Site =', @Definition) AS SiteAssignPos,
    CHARINDEX(N'@OrigSite =', @Definition) AS OrigSiteAssignPos;
```

Then extract surrounding source using the returned positions. Do not modify staging site, standard trigger, or replication rules until these assignments are known.
