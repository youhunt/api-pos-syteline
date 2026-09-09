# IDO Router

```text
ido/csv-to-co/
  01-SMKRSCPosInbounds.md
  02-SMKRSCPosBatches.md

ido/shipment/
  03-SMK069ShipmentScheduler.md
```

CSV/CO IDO menangani inbound, batch, staging, dan service methods untuk Receive/Validate/Process.
Shipment IDO menangani `ue_SMK069ShipmentTransport`, scheduler, dashboard, queue, retry, dan outbound transport.

Ketika menambah IDO atau method baru, tempatkan dokumentasinya di domain yang sesuai dan jangan mengubah metadata domain lain tanpa dependency yang eksplisit.
