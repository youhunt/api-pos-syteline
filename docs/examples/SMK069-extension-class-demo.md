# SMK069 Extension Class Demo

Contoh kecil dan terisolasi untuk belajar IDO Extension Class di Infor SyteLine / Mongoose.

Jangan pasang contoh ini pada `ue_SMK069ShipmentTransport`. Gunakan IDO demo terpisah:

```text
IDO       : ue_SMK069Test
Assembly  : ue_SMK069TestExtensions
Namespace : SMK069Test
Class     : SMK069TestExtension
```

## Empat pola yang dicontohkan

| Method | Yang dipelajari |
|---|---|
| DemoPing | memanggil Extension Class sederhana |
| DemoEcho | input + output langsung dari C# |
| DemoCallSp | Extension Class memanggil Stored Procedure |
| DemoCallSpGetValue | Extension Class memanggil SP dan mengambil OUTPUT |

## 1. Apply dua Stored Procedure

Apply satu per satu:

```text
database/procedures/examples/SMK069TestSimpleSp.sql
database/procedures/examples/SMK069TestAddNumbersSp.sql
```

## 2. Buat IDO demo

Buat IDO terpisah:

```text
IDO Name : ue_SMK069Test
```

Jika tenant mewajibkan Primary Base Table untuk IDO baru, gunakan sebuah tabel demo kecil yang dibuat melalui **SQL Tables**. Jangan memakai Shipment table hanya untuk demo ini.

## 3. Register Stored Procedure methods pada IDO

### SMK069TestSimpleSp

```text
Method Type      : Stored Procedure - Standard Method
Stored Procedure : SMK069TestSimpleSp
Transactional    : unchecked
Parameters       : tidak ada
```

### SMK069TestAddNumbersSp

```text
Method Type      : Stored Procedure - Standard Method
Stored Procedure : SMK069TestAddNumbersSp
Transactional    : unchecked
```

Parameter order:

```text
1 A        IN
2 B        IN
3 Total    OUTPUT
4 Infobar  OUTPUT
```

Setelah membuat method, gunakan **Resync Parameters** bila perlu.

## 4. Buat assembly

```text
Assembly Name : ue_SMK069TestExtensions
Assembly Type : Build From Source
Language      : C#
```

Masukkan source:

```text
extension-classes/examples/SMK069TestExtension.cs
```

Build sampai muncul:

```text
Assembly compiled and updated successfully.
```

## 5. Register Extension Class methods

Pilih:

```text
Assembly  : ue_SMK069TestExtensions
Namespace : SMK069Test
Class     : SMK069TestExtension
```

Daftarkan:

```text
DemoPing
DemoEcho
DemoCallSp
DemoCallSpGetValue
```

Semua boleh:

```text
Method Type   : Extension Class - Standard Method
Transactional : unchecked
```

## Expected test

### DemoPing

Tidak ada input.

Expected:

```text
ReturnValue = 0
Infobar     = DemoPing berhasil dipanggil.
```

### DemoEcho

Input:

```text
Text = Yohan
```

Expected:

```text
Result  = Halo Yohan
Infobar = DemoEcho selesai.
```

### DemoCallSp

Tidak ada input bisnis.

Expected:

```text
ReturnValue = 0
Infobar = SMK069TestSimpleSp berhasil dipanggil dari Extension Class.
```

Alurnya:

```text
IDO method DemoCallSp
  -> C# Extension Class
     -> Context.Commands.Invoke
        -> IDO stored-procedure method SMK069TestSimpleSp
           -> dbo.SMK069TestSimpleSp
```

### DemoCallSpGetValue

Input:

```text
A = 10
B = 20
```

Expected:

```text
Total   = 30
Infobar = SMK069TestAddNumbersSp berhasil. 10 + 20 = 30
```

Alurnya:

```text
IDO method DemoCallSpGetValue
  -> C# Extension Class
     -> Context.Commands.Invoke
        -> IDO stored-procedure method SMK069TestAddNumbersSp
           -> dbo.SMK069TestAddNumbersSp
           -> Total OUTPUT
        <- response.Parameters[2]
  <- Total = 30
```

## Kenapa SP dipanggil lewat Context.Commands.Invoke?

Ini mengikuti pola tenant yang sudah berhasil digunakan pada Shipment:

```text
Extension Class
-> Context.Commands.Invoke(...)
-> IDO Stored Procedure Method
-> SQL Stored Procedure
```

Jadi contoh tidak memakai `System.Data`, connection string, atau direct SQL connection dari C#.
