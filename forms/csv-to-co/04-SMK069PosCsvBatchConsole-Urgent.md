# SMK POS CSV TO BLANKET CO — Urgent Fields

**Date:** 14 October 2026  
**Scope:** CSV / POS inbound → Blanket Customer Order  
**Form:** `ue_SMK069PosCsvBatchConsole` (caption "SMK POS CSV TO BLANKET CO")

## Requirement

Besides Postman, the CSV console is used to test the Urgent flag. The detail grid must show, beside Is Peak Season:

```text
Caption   : Is Urgent            Field: is_urgent      INT            checkbox, read-only
Caption   : Urgent Remark        Field: urgent_remark  NVARCHAR(255)  text, read-only
Position  : right after Is Peak Season
```

Both columns bind to the same detail collection as CustPo (`object2`, IDO `ue_SMK069PosCsvUpload`, table `dbo.ue_SMK069_pos_csv_upload_mst`). Patch 37 adds the supporting columns to that table.

## CSV contract

Both CSV headers are optional. See `docs/csv-to-co/50-urgent-flag.md`, section "Jalur CSV — Patch 37".

```text
is_urgent      aliases: isurgent, "Is Urgent", Is_Urgent       1 -> 1, anything else -> 0
urgent_remark  aliases: urgentremark, "Urgent Remark"          optional, max 255
```

## Order of work

1. Run `database/patches/csv-to-co/2026-10-14-smk069-37-urgent-flag-csv.sql` (requires Patch 36).
2. Resynchronize IDO `ue_SMK069PosCsvUpload`; confirm properties `IsUrgent` and `UrgentRemark` exist.
3. Add the grid columns, either way:

**A. Import the prepared form XML** (`forms/csv-to-co/exports/ue_SMK069PosCsvBatchConsole-DEV-urgent-2026-10-14.xml`). Keep `...-before-urgent-2026-10-14.xml` as the rollback file. If the import is refused because the form is checked out, check it in (or unlock it) first.

**B. Manual**, in Form Editor on `ue_SMK069PosCsvBatchConsole`:

~~~text
Grid          : FormCollectionGrid1_SITE (detail grid)
Column 1      : Name gridColumnIsUrgent       Caption "Is Urgent"       Data Source object2.IsUrgent       Checkbox, Read Only
Column 2      : Name gridColumnUrgentRemark   Caption "Urgent Remark"   Data Source object2.UrgentRemark   Text, Read Only, width ~30
Order         : right after "Is Peak Season", before "Co Num"
~~~

Do not bind them to form variables; they must show the persisted row value from `ue_SMK069PosCsvUpload`, the same rule as Peak Season.

If Is Urgent shows `0`/`1` instead of a checkbox, change the column control to Checkbox the same way the Is Peak Season column was set.

## Checklist

~~~text
[ ] Patch 37 applied (Apply Database: PATCH-37 SUCCESS)
[ ] IDO ue_SMK069PosCsvUpload exposes IsUrgent and UrgentRemark
[ ] Grid shows Is Urgent (checkbox) and Urgent Remark, both read-only
[ ] Upload tests/payloads/csv-urgent/csv-u2-urgent-and-normal.csv: row 1 checked + "Kirim pagi", row 2 unchecked
[ ] co_bln_mst line values match the grid
~~~
