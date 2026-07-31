# Evidence — SMK069 Runtime Reached SyteLine Replication Framework

Date: 31 July 2026
Database: `LENSA_SL_CSI_BAK`

## Runtime result

After the staging group, customer, warehouse, currency, item validation, and site-context correction progressed further, execution returned:

```text
Error 50000 pada dbo.RaiseErrorSp line 121:
Not one Replication Rule where Disabled is No and Target Site is DEFAULT exists
for Replication Category Object that has [Object Name: DeleteRemoteNotesSp].
```

## Confirmed interpretation

This is no longer a staging-data or item-master validation error.

The direct `co_mst` insertion reached standard SyteLine trigger/replication logic. A standard path attempted to use `DeleteRemoteNotesSp` through Replication Category `Object`, targeting site `DEFAULT`, but the tenant/database did not contain exactly one active matching replication rule.

The procedure transaction failed and rolled back. A Customer Order success result is not confirmed.

## Safety boundary

Do not resolve this by globally disabling triggers or by inserting an unverified replication rule.

Before changing configuration or trigger logic, identify:

1. The exact trigger/procedure that calls `DeleteRemoteNotesSp`.
2. The local/current site represented by the application and SQL session.
3. Whether `DEFAULT` is the actual intended site or an incomplete session/configuration fallback.
4. Whether the backup DEV database is missing replication metadata that exists in the normal application environment.

## Next read-only diagnostic

```sql
SELECT
    OBJECT_SCHEMA_NAME(m.object_id) AS SchemaName,
    OBJECT_NAME(m.object_id) AS ObjectName,
    o.type_desc AS ObjectType
FROM sys.sql_modules AS m
JOIN sys.objects AS o
  ON o.object_id = m.object_id
WHERE m.definition LIKE N'%DeleteRemoteNotesSp%'
ORDER BY ObjectType, SchemaName, ObjectName;

SELECT
    DB_NAME() AS CurrentDatabase,
    CONTEXT_INFO() AS ContextInfoBinary,
    CONVERT(VARCHAR(128), CONTEXT_INFO()) AS ContextInfoText;
```

Return the result before altering standard triggers or replication configuration.
