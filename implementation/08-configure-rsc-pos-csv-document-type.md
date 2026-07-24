# Implementation 08 — Configure RSC POS CSV Document Type

## Problem

The Attached Documents form requires a valid Document Type. The tenant currently only exposes predefined types such as `AttachedImage`, `AttachedReportDocument`, `CfgDbFile`, and `PDF`. A CSV-specific type must be created before the POS template can be imported.

## Step 1 — Register the CSV media type

Open the **Media Types** form and create a record:

```text
Active         : checked
Allow Upload   : checked
File Extension : csv
Media Type     : text/csv
BLOB Format    : blank
```

Save the record.

## Step 2 — Create the document type

Open the **Document Types** form and create:

```text
Document Type  : RSC_POS_CSV
Description    : RSC POS CSV import file
Storage Method : Database
File Extension : csv
Media Type     : text/csv
Auto Populate  : unchecked
```

For a Database storage method, no File Server, Logical Folder, or File Specification is required.

If the tenant restricts document types by Shared Groups, add the group used by the POS import users.

## Step 3 — Import the CSV

Return to **Attached Documents** for the selected inbound record and select:

```text
Document Name : POS_MINIMAL_V1
Description   : RSC POS minimal CSV test
Document Type : RSC_POS_CSV
```

The form should populate:

```text
Storage Method : Database
File Extension : csv
Media Type     : text/csv
```

Click **Import**, select `pos-minimal-v1.csv`, and save.

## Acceptance criteria

```text
[ ] RSC_POS_CSV appears in the Document Type drop-down
[ ] Import button is enabled
[ ] CSV file can be selected and saved
[ ] Document Sequence is assigned
[ ] View or Export can retrieve the file
[ ] Attachment is linked to the selected ue_SMKRSCPosInbounds RowPointer
```

Do not use `PDF`, `AttachedImage`, or another unrelated predefined type for CSV files.
