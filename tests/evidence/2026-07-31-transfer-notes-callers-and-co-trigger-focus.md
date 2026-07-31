# Evidence — TransferNotesToSiteSp Callers and CO Trigger Focus

Date: 31 July 2026
Tenant database: `LENSA_SL_CSI_BAK`

## Tenant-returned callers

The tenant search returned multiple stored procedures and triggers that reference `TransferNotesToSiteSp`, including:

```text
ARPayPostRemoteCopyNotesSp
ChangeReportsToCopyChartSp
CopyNotesFromOrigSiteSp
ERS_SSSFSSroCopyCreateSroSp
FinRptToSiteCopySp
FinRptXMLBufCopyNotesSp
InitDatarep_object_categorySp
RepCoSp
RepCoSp_ItalyCountryPack
SSSFSMultiSiteSroCopySp
SSSFSSroCopyCreateSroSp
SSSFSSroCopyCreateSroSp_ItalyCountryPack
co_bln_mstIup
co_mstIup
coitem_mstIup
FSObjectNotesIup
ObjectNotesIup
transfer_mstIup
trnitem_mstIup
```

## Relevant CO path

The controlled procedure inserts the Customer Order header into `dbo.co_mst` before inserting any `dbo.coitem_mst` lines.

The replication error occurred during that execution before line creation was confirmed. Therefore the most likely direct caller for this runtime is:

```text
dbo.co_mstIup on dbo.co_mst
```

`dbo.coitem_mstIup` is also a known caller, but its returned source block shows note transfer only when:

```sql
@CoOrigSite <> @ShipSite
AND dbo.SkipRemoteUpdate() = 0
AND @CoType <> 'E'
```

The current staging procedure maps both `co_orig_site` and `ship_site` to `@SiteRef` on line insertion, and line insertion occurs after the header. This makes `coitem_mstIup` less likely to be the source of the current header-stage error.

## Limitation of the previous query

The previous `SUBSTRING` query used the first occurrence of `TransferNotesToSiteSp` in each module. For `co_mstIup`, that first occurrence was inside the trigger history/comment block rather than the executable call.

## Next read-only query

Extract the executable call in `co_mstIup` using an exact `EXEC` pattern:

```sql
DECLARE @Definition NVARCHAR(MAX),
        @Position   INT;

SELECT @Definition = sm.definition
FROM sys.sql_modules AS sm
WHERE sm.object_id = OBJECT_ID(N'dbo.co_mstIup');

SET @Position = CHARINDEX
(
    N'EXEC @Severity = dbo.TransferNotesToSiteSp',
    @Definition
);

SELECT
    @Position AS CallPosition,
    SUBSTRING
    (
        @Definition,
        CASE WHEN @Position > 1800 THEN @Position - 1800 ELSE 1 END,
        5000
    ) AS ExecutableReferenceBlock;
```

If `CallPosition = 0`, repeat with the less-specific pattern:

```sql
SET @Position = CHARINDEX(N'dbo.TransferNotesToSiteSp', @Definition);
```

Do not alter the trigger or replication configuration before the executable surrounding condition is captured.
