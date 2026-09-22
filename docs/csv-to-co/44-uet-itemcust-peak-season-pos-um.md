# UET itemcust — Peak Season & POS U/M

**Date:** 22 September 2026  
**Scope:** CSV / POS inbound → Blanket Customer Order  
**SyteLine area:** Customer Contracts / item-customer setup

## Purpose

Tambahan UET dibuat pada `itemcust_mst` untuk menyediakan konfigurasi item-customer yang dibutuhkan oleh integrasi POS, khususnya:

```text
1. Flag Peak Season
2. POS U/M
```

Konfigurasi ini ditampilkan pada form **Customer Contracts** dan menjadi referensi tambahan untuk mapping/validasi POS.

## UET User Fields

### 1. Peak Season

```text
User Field Name : Uf_SMK069_is_peak_season
User Data Type  : <blank / tidak menggunakan UDT>
Data Type       : int
Initial Value   : 0
Description     : Peak Season flag untuk kebutuhan integrasi POS
```

Semantik:

```text
0 = Normal / non-peak
1 = Peak Season
```

Pada UI, field ditampilkan sebagai checkbox dengan caption:

```text
Is Peak Season?
```

### 2. POS U/M

```text
User Field Name : Uf_SMK069_pos_um
User Data Type  : UMType
Data Type       : nvarchar
Precision       : 3
Description     : POS U/M untuk kebutuhan mapping integrasi POS
```

Pada UI, field ditampilkan sebagai field/dropdown:

```text
POS U/M
```

## UET Class

Class yang dibuat:

```text
Class Name  : SMK069_CL_itemcust
Label       : <blank>
Description : <blank>
```

Field yang menjadi anggota class:

```text
SMK069_CL_itemcust.Uf_SMK069_is_peak_season
SMK069_CL_itemcust.Uf_SMK069_pos_um
```

## Table Extension

Class diterapkan ke:

```text
Table Name         : itemcust_mst
Class Name         : SMK069_CL_itemcust
Active             : 1
Extend All Records : 1
Rule               : <blank>
```

Artinya seluruh record `itemcust_mst` mendapatkan extension field UET tersebut.

## Customer Contracts UI

Hasil konfigurasi pada form **Customer Contracts**:

```text
POS U/M          : field/dropdown
Is Peak Season?  : checkbox
```

Posisi kedua field berada pada area detail Customer Contracts untuk kombinasi customer-item.

Observed UI evidence pada DEV menunjukkan:

```text
POS U/M
[ ] Is Peak Season?
```

## Relationship to POS payload

Payload POS menggunakan field:

```json
"is_peak_season": 1
```

Field payload tersebut disimpan ke inbound/temp integration staging sebagai:

```text
is_peak_season
```

UET pada `itemcust_mst` bukan pengganti field payload. UET menyediakan **master/configuration context** pada customer-item, sedangkan payload `is_peak_season` merupakan flag transaksi yang dikirim oleh POS.

## Mapping ownership

`dbo.ue_SMK069_pos_sales_inbound_mapping_view` dikelola oleh Eva / SMK.

UET fields ini disiapkan agar view/mapping SMK dapat menggunakan konfigurasi customer-item yang relevan. Repository ini tidak membuat ALTER VIEW yang bersaing dengan perubahan Eva/SMK.

## Deployment / migration note

Konfigurasi ini adalah **Mongoose UET metadata**, bukan SQL patch numbered seperti Patch 27/28.

Untuk production baseline, pastikan metadata berikut ikut dipindahkan:

```text
User Field:
  Uf_SMK069_is_peak_season
  Uf_SMK069_pos_um

Class:
  SMK069_CL_itemcust

Class Fields:
  Uf_SMK069_is_peak_season
  Uf_SMK069_pos_um

Extended Table:
  itemcust_mst
  Active = 1
  Extend All Records = 1
```

Setelah deploy ke target environment, buka form **Customer Contracts** dan verifikasi kedua field muncul serta menyimpan nilai.

## Verification checklist

```text
[ ] Uf_SMK069_is_peak_season tersedia
[ ] Data Type = int
[ ] Initial Value = 0
[ ] Uf_SMK069_pos_um tersedia
[ ] User Data Type = UMType
[ ] Physical type = nvarchar(3)
[ ] Class SMK069_CL_itemcust tersedia
[ ] Kedua field menjadi member class
[ ] itemcust_mst menggunakan SMK069_CL_itemcust
[ ] Active = 1
[ ] Extend All Records = 1
[ ] Customer Contracts menampilkan POS U/M
[ ] Customer Contracts menampilkan checkbox Is Peak Season?
```
