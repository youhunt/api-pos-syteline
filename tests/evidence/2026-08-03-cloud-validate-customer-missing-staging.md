# Evidence — Cloud Validate Customer Missing Staging

Date: 3 August 2026
Environment: SyteLine Cloud

## Postman invocation

```text
{{trnurl}}/json/method/ue_SMK069TempSales/ue_SMK069ValidateCustomerSp?parms=DEFAULT,TEST000002,
```

## Response

```json
{
  "Message": null,
  "MessageCode": 0,
  "Parameters": [
    "DEFAULT",
    "TEST000002",
    "Data staging tidak ditemukan untuk SiteRef DEFAULT dan CO Number TEST000002."
  ],
  "ReturnValue": "16"
}
```

## Confirmed interpretation

```text
Cloud endpoint reachable                 : YES
IDO ue_SMK069TempSales reachable         : YES
Method ue_SMK069ValidateCustomerSp found : YES
Parameter order accepted                 : YES
TEST000002 staging group present         : NO
Customer validation reached              : NO, stopped at staging existence check
```

The next controlled cloud step is to load a known staging order such as `TEST000001`, copy its valid business values, insert a new staging group as `TEST000002` through the entity IDO, and then invoke the validation method again.

Do not share the Mongoose session token, OAuth bearer token, client secret, or Postman environment secret in repository evidence or chat.
