# Extension Class Router

```text
extension-classes/csv-to-co/
  SMKRSCPosIntegrationExtension.cs

extension-classes/shipment/
  SMK069ShipmentSenderExtension.cs
  SMK069ShipmentSenderExtension.rev3.cs
  SMK069ShipmentSchedulerRunner.snippet.cs
```

Aturan penting Shipment: `ue_SMK069ShipmentTransport` menggunakan satu extension class yang sama; scheduler runner tidak boleh didaftarkan sebagai extension class kedua untuk IDO yang sama.

Aturan tenant: jangan reintroduce dependency `System.Data` pada Shipment extension; gunakan Mongoose `Context.Commands.Invoke` sesuai implementasi yang sudah berhasil compile.
