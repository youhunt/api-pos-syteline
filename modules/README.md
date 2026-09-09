# Module Router

Repository ini memiliki dua domain runtime yang harus dikembangkan secara terpisah:

1. `csv-to-co` — inbound CSV/JSON/POS sampai menjadi Blanket Customer Order.
2. `shipment` — outbound Shipment SyteLine ke POS API, termasuk retry dan scheduler.

Jangan mencampur tabel, mapping, patch, IDO method, form, atau evidence antar-domain kecuali dependensinya memang didokumentasikan secara eksplisit.

Mulai sesi development baru dari:

- `modules/csv-to-co/README.md`
- `modules/shipment/README.md`

Untuk membuka chat baru yang fokus, gunakan starter prompt:

- `modules/csv-to-co/CHAT-STARTER.md`
- `modules/shipment/CHAT-STARTER.md`

Dokumen handoff lama yang mencampur dua domain dipindahkan ke `docs/archive/` dan hanya dipakai sebagai sejarah, bukan continuation source utama.
