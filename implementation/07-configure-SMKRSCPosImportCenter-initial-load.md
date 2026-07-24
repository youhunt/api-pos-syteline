# Implementation 07 — Configure Initial Load for `SMKRSCPosImportCenter`

## Symptom

Form `SMKRSCPosImportCenter` opens with column headers but no inbound rows, while the same IDO returns data in IDO Data Viewer.

## Cause

The form primary collection has not been queried when the form opens. The form `Initial Command` is blank or not set to `Refresh`.

## Quick Test

Open the form and press `F5` or choose:

```text
Actions -> Refresh
```

If rows appear, the primary IDO and bindings are correct and only the initial command needs correction.

## Required Configuration

Open the form in Web Designer and set:

```text
Form Name        : SMKRSCPosImportCenter
Primary IDO      : ue_SMKRSCPosInbounds
Initial Command  : Refresh
```

For the primary collection, verify:

```text
Collection              : ue_SMKRSCPosInbounds
Order By                : ReceivedDate DESC
Permanent Filter        : blank for initial PoC
Custom Load Method      : blank
Defer Refresh Until Visible : False
Record Cap Override     : blank or a positive value
```

Save and check in the form, unload global form objects, close the old runtime tab, and reopen the form.

## Expected Result

The current inbound record appears automatically when the form opens, without requiring F5.

## Current Test Record

```text
RequestId       : MAN-20260724-142607-6612C69F
SourceSystem    : PIZZAHUT_POS
SourceReference : pos_20260724.csv
Stat            : R
```
