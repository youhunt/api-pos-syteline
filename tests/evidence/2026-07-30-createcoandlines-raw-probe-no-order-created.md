# Evidence — No Customer Order Created by Raw CreateCoAndLines Probe

Date: 30 July 2026

## Environment

```text
Environment                        : DEV
Disposable Customer Order testing : allowed
```

## Verification Query

The following read-only query was executed after the raw malformed `CreateCoAndLines` probe:

```sql
SELECT TOP (20)
       co_num,
       cust_num,
       order_date,
       CreateDate,
       CreatedBy,
       RecordDate,
       UpdatedBy
FROM dbo.co_mst
WHERE RecordDate >= DATEADD(MINUTE, -30, GETDATE())
   OR CreateDate >= DATEADD(MINUTE, -30, GETDATE())
ORDER BY COALESCE(RecordDate, CreateDate) DESC;
```

## Tenant Result

The query executed successfully and the result grid contained no rows.

Confirmed observations:

```text
SQL error                         : none
Rows returned                    : 0
Unexpected recent Customer Order : not found
```

The result-grid columns were present:

```text
co_num
cust_num
order_date
CreateDate
CreatedBy
RecordDate
UpdatedBy
```

## Technical Conclusion

Within the 30-minute verification window, the deliberately malformed raw input probe did not create a Customer Order in `dbo.co_mst`.

This closes the no-order verification gate for the first runtime probe. The next controlled probe may move only one layer deeper by sending Base64 `ew==`, which decodes to malformed JSON `{`.

## Safety Result

```text
No direct SQL insert
No Customer Order deletion
No standard metadata change
No Process/Reprocess logic created
No valid Customer Order payload submitted
```
