# SMK Customer Order Blanket Releases — Urgent Fields

**Date:** 14 October 2026  
**Scope:** Customer Order Blanket Line / Release → urgent visibility  
**Form:** `ue_SMK069_BlanketReleases` (caption "SMK Customer Order Blanket Releases")  
**Primary collection:** `SL.SLCoitems` (`coitem_mst`), filter `CoType = 'B'`

## Requirement

The business must be able to see on this form whether a line is urgent and why. Business decision 14 Oct 2026: both fields are read-only (POS owns the values).

```text
Caption   : Is Urgent       column DB: coitem_mst.Uf_SMK069_is_urgent       INT            checkbox, read-only
Caption   : Urgent Remark   column DB: coitem_mst.Uf_SMK069_urgent_remark   NVARCHAR(255)  text, read-only
Position  : grid, right after the Line column
```

## IDO property names

On IDO `SLCoitems` the UET properties carry the `coi` prefix. The form Data Source uses the property name, not the column name:

```text
object.coiUf_SMK069_is_urgent
object.coiUf_SMK069_urgent_remark
```

(Same pattern as the existing `coiUf_SMK017_Moq`, `coiUf_SMK017_Packaging`, `coiUf_SMK017_Ukuran`.)

## Order of work

1. UET on `coitem_mst` + Impact Schema (done in DEV; see `docs/csv-to-co/50-urgent-flag.md`, "Langkah 1").
2. Run `database/patches/csv-to-co/2026-10-14-smk069-38-urgent-flag-coitem.sql` (requires Patch 36). It fills the new columns for new orders and back-fills existing urgent lines.
3. Make sure the IDO exposes `coiUf_SMK069_is_urgent` and `coiUf_SMK069_urgent_remark`.
4. Add the grid columns, either way:

**A. Import the prepared form XML** (`forms/csv-to-co/exports/ue_SMK069_BlanketReleases-DEV-urgent-2026-10-14.xml`). Keep `...-before-urgent-2026-10-14.xml` as the rollback file. If the import is refused because the form is checked out or locked, check it in (or unlock it) first.

**B. Manual**, in Form Editor on `ue_SMK069_BlanketReleases`:

~~~text
Grid       : FormCollectionGrid (main grid)
Column 1   : Name IsUrgentGridCol       Caption "Is Urgent"       Data Source object.coiUf_SMK069_is_urgent       Checkbox, Read Only
Column 2   : Name UrgentRemarkGridCol   Caption "Urgent Remark"   Data Source object.coiUf_SMK069_urgent_remark   Text, Read Only, width ~30
Order      : right after the "sLine" column (CoLineGridCol), before "Item"
~~~

## What the prepared XML changes

The `urgent` file differs from the `before-urgent` file only by:

- two new grid columns, `IsUrgentGridCol` (ContainerSequence 5) and `UrgentRemarkGridCol` (ContainerSequence 6), both `ReadOnly = True`, TabOrder 0 like the other custom columns in this form;
- `ContainerSequence` +2 for the 99 grid columns that were at sequence 5 or higher (Item and everything to the right).

No scripts, events, variables or other components are touched. Component count 419 → 421, names stay in alphabetical order, grid sequences stay unique 0–105.

The two columns are placed in the grid only. The detail area above the grid (item description, manufacturer group) is unchanged.

## Notes

- Users who saved their own column layout for this form may not see the columns in the new position. Right-click the grid header and show or move the columns.
- A release created manually by the user (next `co_release`) does not receive the urgent value from the SP, so it shows unchecked / empty. See "Form Customer Order Blanket Releases — Patch 38" in `docs/csv-to-co/50-urgent-flag.md`.

## Checklist

~~~text
[ ] Patch 38 applied (PATCH-38 SUCCESS), backfill row count noted
[ ] IDO SLCoitems exposes coiUf_SMK069_is_urgent and coiUf_SMK069_urgent_remark
[ ] Form XML imported (or columns added manually)
[ ] Releases grid shows Is Urgent (checkbox) and Urgent Remark, both read-only
[ ] CO from tests/payloads/csv-urgent/csv-u2-urgent-and-normal.csv: line 1 checked + "Kirim pagi", line 2 unchecked
[ ] Existing CO with urgent from Patch 36 UAT also shows the values (backfill)
~~~
