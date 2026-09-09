# Form Router

```text
forms/csv-to-co/
  01-SMKRSCPosImportCenter.md

forms/shipment/
  02-SMK069ShipmentScheduler.md
```

Form CSV hanya untuk inbound/import/validation/processing menuju Customer Order.
Form Shipment hanya untuk scheduler, dashboard, queue, retry, dan kontrol outbound Shipment.

Jangan menambahkan secondary collection atau event lintas domain hanya untuk memudahkan tampilan; gunakan boundary modul yang jelas.
