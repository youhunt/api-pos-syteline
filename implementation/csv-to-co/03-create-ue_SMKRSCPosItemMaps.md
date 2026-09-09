# Implementation 03 — Create `ue_SMKRSCPosItemMaps`

## Scope

Create the item-mapping entity IDO used by minimal CSV validation and quantity conversion.

```text
IDO Project        : ue_SMKRSCPos
Final IDO Name     : ue_SMKRSCPosItemMaps
Architectural Role : Entity IDO
Primary Base Table : ue_SMK_RSC_POS_ItemMap_mst
Physical Table     : dbo.ue_SMK_RSC_POS_ItemMap_mst
Table Alias        : im
```

Use the exact base-table name shown by the tenant dropdown if metadata displays the logical name without `ue_`.

## Wizard Values

```text
Project Name       : ue_SMKRSCPos
Primary Base Table : ue_SMK_RSC_POS_ItemMap_mst
Table Alias        : im
IDO Name           : ue_SMKRSCPosItemMaps
Extends             : blank
```

Avoid duplicate prefixing such as `ue_ue_SMKRSCPosItemMaps`.

## Property Mapping

| Column | IDO Property |
|---|---|
| `source_system` | `SourceSystem` |
| `target_site` | `TargetSite` |
| `pos_item_code` | `PosItemCode` |
| `pos_item_desc` | `PosItemDesc` |
| `pos_category` | `PosCategory` |
| `item` | `Item` |
| `pos_u_m` | `PosUM` |
| `u_m` | `UM` |
| `qty_conv_factor` | `QtyConvFactor` |
| `inventory_flag` | `InventoryFlag` |
| `active_flag` | `ActiveFlag` |
| `effective_date` | `EffectiveDate` |
| `expiration_date` | `ExpirationDate` |
| `notes` | `Notes` |
| `CreateDate` | `CreateDate` |
| `CreatedBy` | `CreatedBy` |
| `InWorkflow` | `InWorkflow` |
| `NoteExistsFlag` | `NoteExistsFlag` |
| `RecordDate` | `RecordDate` |
| `RowPointer` | `RowPointer` |
| `SiteRef` | `SiteRef` |
| `UpdatedBy` | `UpdatedBy` |

Review `PosUM` and `UM` manually after Massage Property Names because the wizard may generate `PosUm` and `Um`.

## Composite Primary Key

```text
1. SourceSystem  -> source_system
2. TargetSite    -> target_site
3. PosItemCode   -> pos_item_code
```

All three key properties must be non-nullable. `RowPointer` remains a framework identifier and is not the business primary key.

## Save and Check In

```text
Save
Check In
```

Suggested check-in comment:

```text
Create ue_SMKRSCPosItemMaps entity IDO for POS item mapping
```

## Web Client Cache Refresh

After check-in:

```text
1. Configuration Manager -> Discard IDO Cache
2. Reload the web-client session or log off/login when required
3. Reopen IDO Data Viewer
```

## Smoke Test

Select:

```text
IDO : ue_SMKRSCPosItemMaps
```

Suggested properties:

```text
SourceSystem
TargetSite
PosItemCode
PosItemDesc
PosCategory
Item
PosUM
UM
QtyConvFactor
InventoryFlag
ActiveFlag
EffectiveDate
ExpirationDate
RowPointer
SiteRef
```

Expected before seed data exists:

```text
Load Collection succeeds
0 records returned is acceptable
```

## Stop Point

```text
[ ] Final IDO name is ue_SMKRSCPosItemMaps
[ ] No duplicated ue_ prefix
[ ] Composite key sequence is 1/2/3
[ ] Framework properties exist
[ ] IDO is checked in
[ ] Load Collection succeeds
```
