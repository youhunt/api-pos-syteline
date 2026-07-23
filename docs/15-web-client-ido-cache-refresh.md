# 15 — Web Client IDO Cache Refresh (SyteLine/Mongoose 10)

## Scope

Environment project ini menggunakan SyteLine/Mongoose 10 dengan web client. Panduan WinStudio/Windows client tidak berlaku untuk workflow harian project ini.

## Why a new IDO is not immediately visible

Setelah IDO baru dibuat dan di-check-in, metadata sudah tersimpan, tetapi IDO Runtime dan sesi web client yang sedang aktif dapat masih menggunakan metadata lama dari cache.

## Recommended workflow

1. Save dan Check In IDO.
2. Pada Configuration Manager untuk konfigurasi yang digunakan, klik `Discard IDO Cache`.
3. Pada web client, buka User Preferences dan aktifkan `Unload IDO Metadata With Forms` bila tersedia.
4. Tutup IDO Data Viewer dan seluruh form yang memakai IDO terkait.
5. Buka kembali form/IDO Data Viewer dan periksa daftar IDO.
6. Bila IDO masih belum dikenali, lakukan sign out lalu sign in untuk membuat sesi web baru.

## Server farm

Jika environment memakai lebih dari satu application server, gunakan `Refresh Farm Metadata` untuk membersihkan cache IDO pada seluruh node, bukan hanya cache satu server.

## Important correction

Jangan menggunakan langkah berikut pada environment ini:

- WinStudio `Unload All Global Form Objects`;
- penghapusan file cache XML lokal WinStudio;
- process default `Persist WinStudio metadata cache` sebagai solusi utama.

Langkah tersebut khusus Windows client/WinStudio dan tidak mewakili workflow web client SyteLine/Mongoose 10 yang dipakai project ini.

## Practical development cycle

```text
Create/modify IDO
    ↓
Save + Check In
    ↓
Discard IDO Cache
    ↓
Close affected web forms
    ↓
Reopen and test
    ↓
Sign out/sign in only when still stale
```

## Current observed tenant behavior

Pada tenant project ini, IDO baru belum selalu muncul pada sesi web yang aktif sampai:

1. `Discard IDO Cache` dijalankan; dan
2. user sign out lalu sign in kembali.

Behavior ini dicatat sebagai fakta environment saat ini dan menjadi prosedur sementara sampai opsi unload metadata pada web client diverifikasi langsung pada tenant.
