# SMK_RSC_POS_TranLine_mst

## Identity

```text
Metadata object : SMK_RSC_POS_TranLine_mst
Physical table  : dbo.ue_SMK_RSC_POS_TranLine_mst
Purpose         : Detail item dan quantity per transaksi
```

## Primary Key

```text
batch_num + trans_num + line_num
```

## Custom Columns

| Column | Data Type | Null | Default | Description |
|---|---|---:|---|---|
| `batch_num` | `nvarchar(30)` | No |  | Parent batch |
| `trans_num` | `nvarchar(50)` | No |  | Parent transaction |
| `line_num` | `int` | No |  | Nomor line |
| `parent_line_num` | `int` | Yes |  | Parent modifier/package line |
| `pos_item_code` | `nvarchar(50)` | No |  | Kode item asli POS |
| `item` | `ItemType` | Yes |  | Item hasil mapping SyteLine |
| `item_desc` | `nvarchar(200)` | Yes |  | Deskripsi item sumber |
| `line_type` | `nchar(1)` | No | `N'I'` | I=Item, M=Modifier, P=Package, D=Discount, S=Service |
| `qty` | `QtyUnitType` | No | `0` | Quantity sumber saat ini |
| `u_m` | `UMType` | Yes |  | U/M hasil mapping |
| `unit_price` | `CostPrcType` | No | `0` | Harga satuan |
| `gross_amt` | `AmountType` | No | `0` | Nilai kotor line |
| `discount_amt` | `AmountType` | No | `0` | Diskon line |
| `tax_amt` | `AmountType` | No | `0` | Pajak line |
| `service_amt` | `AmountType` | No | `0` | Service charge line |
| `net_amt` | `AmountType` | No | `0` | Nilai bersih line |
| `tax_code` | `nvarchar(20)` | Yes |  | Kode pajak POS |
| `promo_code` | `nvarchar(30)` | Yes |  | Kode promo |
| `void_flag` | `FlagNyType` | No | `0` | Penanda line void |
| `stat` | `nchar(1)` | No | `N'N'` | Status |
| `validation_msg` | `nvarchar(1000)` | Yes |  | Ringkasan validasi |
| `error_msg` | `nvarchar(4000)` | Yes |  | Error terakhir |
| `syteline_ref` | `nvarchar(50)` | Yes |  | Referensi hasil SyteLine |
| `process_date` | `DateType` | Yes |  | Waktu proses |

## Important Design Note

Sebelum inventory processing final, pertimbangkan memisahkan:

```text
pos_qty       = quantity asli POS
syteline_qty  = quantity setelah konversi
pos_u_m       = U/M asli POS
u_m           = U/M SyteLine
```

Data sumber tidak boleh ditimpa oleh hasil mapping.

## Candidate Indexes

```text
IX_ue_SMK_RSC_POS_TranLine_01
SiteRef, batch_num, trans_num

IX_ue_SMK_RSC_POS_TranLine_02
SiteRef, pos_item_code, stat

IX_ue_SMK_RSC_POS_TranLine_03
SiteRef, item
```

## Validation Rules

- Parent transaction harus ada.
- `line_num > 0`.
- `parent_line_num` harus menunjuk line valid bila terisi.
- `pos_item_code` wajib.
- Mapping item harus aktif dan berlaku pada business date.
- `gross_amt` dibandingkan dengan `qty × unit_price` sesuai aturan rounding.
- `net_amt` dibandingkan dengan gross, discount, tax, dan service.
- Void line diperlakukan sesuai spesifikasi resmi source.

## Example

```text
batch_num       : SMKPOS-20260723-000001
trans_num       : TRX-PH001-00001234
line_num        : 1
pos_item_code   : PIZZA-SUPREME-L
item            : FG-PIZZA-00001
line_type       : I
qty             : 1
u_m             : EA
unit_price      : 150000
net_amt         : 148500
stat            : V
```
