# PROD Shipment config URL width correction

Date: 2026-09-30
Environment: PROD
Object: dbo.ue_SMK069_shipment_api_config_mst

Initial Apply Database of 080 failed with SQL Server truncation on EndpointUrl
because the SQL Tables metadata had EndpointUrl length 1. Inspection also showed
LoginUrl length 1 and AuthValue length 2.

Confirmed current UAT/TRN physical contract in repository reference:

- EndpointUrl nvarchar(1000)
- LoginUrl nvarchar(1000)
- AuthValue nvarchar(2000)

Operator corrected EndpointUrl and LoginUrl to length 1000 through SQL Tables and
re-ran Update Current Table. PROD config now shows the confirmed PROD URLs:

- https://api-prod.pizzahut.co.id/inventory-phi/v1/infor_dn
- https://api-prod.pizzahut.co.id/service-auth/login-once

AuthValue remains to be verified/corrected to length 2000 before declaring the
config-table physical contract complete.
