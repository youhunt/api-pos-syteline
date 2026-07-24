# Implementation 09 — Test Attached Document Through REST v1

## Purpose

Membuktikan attachment CSV yang ditautkan ke `ue_SMKRSCPosInbounds` dapat diunduh kembali melalui REST sebelum parser CSV dibuat.

## Environment Decision

Environment project telah terbukti stabil menggunakan REST API version 1 melalui base URL:

```text
http://tgi-syteline/IDORequestService/MGRESTService.svc
```

Walaupun endpoint REST v2 `/IDORequestService/ido/docobj/list` tersedia pada dokumentasi generik, pada tenant ini endpoint tersebut menghasilkan HTTP 500. Untuk PoC dan troubleshooting, gunakan REST v1 secara konsisten.

## Required Values

```text
IDO         : ue_SMKRSCPosInbounds
RowPointer  : GUID lengkap dari record inbound
DocumentSeq : 1
DocumentName: POS_MINIMAL_V1
```

Gunakan `RowPointer`, bukan `InboundId`.

## Recommended Download Test

```http
GET http://tgi-syteline/IDORequestService/MGRESTService.svc/io/downloaddocobj/?ido=ue_SMKRSCPosInbounds&rp=<ROWPOINTER>&refseq=1
```

Header:

```text
Authorization: <MONGOOSE_TOKEN>
```

Alternatif menggunakan document name:

```http
GET http://tgi-syteline/IDORequestService/MGRESTService.svc/io/downloaddocobj/?ido=ue_SMKRSCPosInbounds&rp=<ROWPOINTER>&docname=POS_MINIMAL_V1
```

`refseq=1` direkomendasikan untuk pengujian awal karena sequence sudah terlihat pada Attached Documents dan menghindari perbedaan nama dokumen.

## Expected Result

Response berupa binary stream `application/octet-stream`. Di Postman gunakan `Send and Download` atau `Save Response` dan simpan sebagai file `.csv`.

Isi file harus tetap:

```csv
business_date,trans_num,pos_item_code,pos_qty,total_amt
2026-07-23,TRX001,PIZZA001,2,200000
2026-07-23,TRX001,DRINK001,1,25000
2026-07-23,TRX002,PIZZA002,1,125000
```

## Troubleshooting

Jika masih HTTP 500:

1. pastikan `RowPointer` lengkap 36 karakter;
2. pastikan header `Authorization` menggunakan token mentah tanpa `Bearer`;
3. coba `refseq=1` sebelum `docname`;
4. uji `Export` dari Attached Documents untuk memastikan file tersedia;
5. akses endpoint dari localhost server untuk melihat detail exception bila custom errors menyembunyikannya.

## Acceptance

```text
[ ] REST v1 endpoint returns HTTP 200
[ ] CSV can be saved from Postman
[ ] Downloaded content matches original CSV
```
