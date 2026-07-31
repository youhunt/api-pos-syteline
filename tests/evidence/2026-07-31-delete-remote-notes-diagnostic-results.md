# Evidence — DeleteRemoteNotesSp Diagnostic Results

Date: 31 July 2026
Database: `LENSA_SL_CSI_BAK`

## Runtime blocker

The controlled Customer Order execution reached standard SyteLine trigger/replication processing and returned:

```text
Error 50000 pada dbo.RaiseErrorSp line 121:
Not one Replication Rule where Disabled is No and Target Site is DEFAULT exists
for Replication Category Object that has [Object Name: DeleteRemoteNotesSp].
```

## Read-only diagnostic results

Objects whose definitions reference `DeleteRemoteNotesSp`:

```text
dbo.DeleteRemoteNotesSp          SQL_STORED_PROCEDURE
dbo.InitDatarep_object_categorySp SQL_STORED_PROCEDURE
dbo.TransferNotesToSiteSp         SQL_STORED_PROCEDURE
```

Current SQL session result after the processing procedure returned:

```text
CurrentDatabase   : LENSA_SL_CSI_BAK
ContextInfoBinary : NULL
ContextInfoText   : NULL
```

The current procedure restores the previous context after success/failure, so a NULL value observed after the call does not prove that the temporary site context was absent during the `co_mst` insert.

`site_mst` contains the target site:

```text
site      : Default
site_name : Default
type      : S
```

## Interpretation

```text
1. The target site DEFAULT exists in site_mst.
2. The current blocker is an absent or non-unique enabled replication rule for category Object / object DeleteRemoteNotesSp / target DEFAULT.
3. The result is consistent with an incomplete replication configuration in the backup database, or with standard note-transfer logic being reached in a context where that rule is expected.
4. No trigger, replication rule, or standard stored procedure was modified.
```

## Next read-only step

Inspect only the definitions around the call chain before deciding whether the issue is backup configuration or a safely skippable note-transfer branch:

```sql
SELECT
    OBJECT_SCHEMA_NAME(object_id) AS SchemaName,
    OBJECT_NAME(object_id) AS ObjectName,
    definition
FROM sys.sql_modules
WHERE object_id IN
(
    OBJECT_ID(N'dbo.DeleteRemoteNotesSp'),
    OBJECT_ID(N'dbo.InitDatarep_object_categorySp'),
    OBJECT_ID(N'dbo.TransferNotesToSiteSp')
);
```

Do not create a replication rule or disable a trigger until the exact condition that invokes `DeleteRemoteNotesSp` is understood.
