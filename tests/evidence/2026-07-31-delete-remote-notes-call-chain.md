# Evidence — DeleteRemoteNotesSp Call Chain

Date: 31 July 2026
Tenant database: `LENSA_SL_CSI_BAK`

## Runtime blocker

The controlled Customer Order processing test returned:

```text
Error 50000 pada dbo.RaiseErrorSp line 121:
Not one Replication Rule where Disabled is No and Target Site is DEFAULT exists
for Replication Category Object that has [Object Name: DeleteRemoteNotesSp].
```

## Tenant SQL-module evidence

The tenant returned these objects containing `DeleteRemoteNotesSp`:

```text
dbo.DeleteRemoteNotesSp
dbo.InitDatarep_object_categorySp
dbo.TransferNotesToSiteSp
```

### DeleteRemoteNotesSp

The stored-procedure header states that it is intended to run at a remote site and removes notes associated with a single remote record. The procedure exists in the database; the runtime error is not caused by a missing stored procedure.

### InitDatarep_object_categorySp

The initialization XML contains a system object entry:

```text
category="A/R"
object_name="DeleteRemoteNotesSp"
object_type="2"
to_object_name="DeleteRemoteNotesSp"
retain_site="1"
```

This confirms the method is registered as a data-replication object in standard initialization metadata. It does not prove that an enabled runtime Replication Rule exists for target site `DEFAULT` and category `Object`.

### TransferNotesToSiteSp

The tenant source shows two execution paths for deleting notes at the destination before transferring notes:

```text
Same database/server path:
@RemoteDbName + 'DeleteRemoteNotesSp'

Remote path:
dbo.RemoteMethodCallSp
    @Site       = @ToSite
    @IdoName    = 'SL.SLObjectNotes'
    @MethodName = 'DeleteRemoteNotesSp'
```

The runtime error matches the second path: `RemoteMethodCallSp` attempted to resolve an enabled Replication Rule for target site `DEFAULT` and method `DeleteRemoteNotesSp`.

## Confirmed interpretation

```text
DeleteRemoteNotesSp exists                         : YES
DeleteRemoteNotesSp is registered in init metadata : YES
TransferNotesToSiteSp can call it remotely          : YES
Enabled runtime rule for target DEFAULT             : NOT FOUND by standard framework
```

The current blocker is therefore replication-rule resolution during the standard note-transfer path, not staging validation, item validation, or the existence of `DeleteRemoteNotesSp`.

Do not resolve this by globally disabling triggers or inserting an unverified replication rule.

## Next read-only step

Identify the object that invokes `TransferNotesToSiteSp` during the `co_mst` insert:

```sql
SELECT
    OBJECT_SCHEMA_NAME(o.object_id) AS SchemaName,
    o.name AS ObjectName,
    o.type_desc AS ObjectType,
    OBJECT_SCHEMA_NAME(t.parent_id) AS ParentSchema,
    OBJECT_NAME(t.parent_id) AS ParentObject,
    SUBSTRING
    (
        m.definition,
        CASE
            WHEN CHARINDEX(N'TransferNotesToSiteSp', m.definition) > 700
            THEN CHARINDEX(N'TransferNotesToSiteSp', m.definition) - 700
            ELSE 1
        END,
        2400
    ) AS ReferenceBlock
FROM sys.sql_modules AS m
JOIN sys.objects AS o
  ON o.object_id = m.object_id
LEFT JOIN sys.triggers AS t
  ON t.object_id = o.object_id
WHERE m.definition LIKE N'%TransferNotesToSiteSp%'
  AND o.object_id <> OBJECT_ID(N'dbo.TransferNotesToSiteSp')
ORDER BY
    o.type_desc,
    SchemaName,
    ObjectName;
```

The returned caller and its surrounding condition are required before deciding whether the backup replication configuration is incomplete or whether a standard note-transfer branch is being entered unexpectedly.
