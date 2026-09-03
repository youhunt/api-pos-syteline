# SMK069 Shipment Extension Build Error — System.Data Reference — 2026-09-03

Tenant Build From Source result for:

```text
Assembly : ue_SMK069ShipmentExtensions
Source   : SMK069ShipmentSenderExtension.cs
```

Compiler errors included:

```text
CS0234 System.Data namespace missing
CS0012 IDbConnection assembly System.Data Version=4.0.0.0 not referenced
CS0246 IDbCommand not found
CS0246 IDbDataParameter not found
CS0246 DbType not found
CS0246 ParameterDirection not found
```

Diagnosis:

```text
Mongoose.IDO.DataAccess.ApplicationDB resolved successfully.
The Build From Source assembly was missing System.Data.dll in References.
```

Required tenant action:

```text
IDO Extension Class Assemblies
-> ue_SMK069ShipmentExtensions
-> References
-> preserve existing defaults
-> append System.Data.dll
-> Save
-> Build Assembly
```

No Shipment source-code logic change is required for this compiler error.
