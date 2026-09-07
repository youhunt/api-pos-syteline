<#
.SYNOPSIS
    Menguji payload Shipment SMK069 langsung ke KACS UAT, di luar SyteLine.

.DESCRIPTION
    Tujuannya mencari field penyebab "1009 Invalid params" tanpa memanggil IDO
    ue_SMK069ShipmentTransport, supaya tidak ada baris ue_SMK069_shipment_api_log_mst
    baru dan RetryCount tidak naik setiap percobaan.

    Skrip mengirim payload yang sama beberapa kali dengan satu variabel diubah
    per percobaan, lalu menampilkan HTTP code + response body-nya berdampingan.

.EXAMPLE
    .\Test-KacsShipmentPayload.ps1

.EXAMPLE
    .\Test-KacsShipmentPayload.ps1 -PayloadFile .\dn25.json -Uom 3 -WhsCode R975

.NOTES
    Password diminta lewat Read-Host -AsSecureString supaya tidak masuk
    riwayat perintah PowerShell. Jangan hardcode di sini.
#>

[CmdletBinding()]
param(
    [string] $BaseUrl     = 'https://api-uat.pizzahut.co.id',
    [string] $Username    = 'kacs',

    # Kosongkan untuk memakai payload DN25 bawaan di bawah.
    [string] $PayloadFile,

    # Nilai tebakan untuk varian V2 dan V3. Ganti kalau dokumen KACS
    # sudah menyebutkan nilai yang benar.
    [int]    $Uom         = 1,
    [string] $WhsCode     = 'R963',

    [int]    $TimeoutSec  = 60
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$LoginUrl    = "$BaseUrl/service-auth/login-once"
$ShipmentUrl = "$BaseUrl/inventory-phi/v1/kacs_dn"

# ---------------------------------------------------------------- payload ---

# Payload DN25 apa adanya, persis seperti yang dihasilkan SMK069BuildShipmentJsonSp.
# Disimpan sebagai string mentah, BUKAN objek: ConvertFrom-Json akan mengubah
# 26.00000000 menjadi 26, padahal justru itu salah satu variabel yang diuji.
$DefaultPayload = @'
{"CUST_CODE":"PHD0001","WHS_CODE":"PLG","DOC_NO":"R260902058","DN_NO":"25","DELIVERY_DATE":"2026-09-04","STORE_ORDER_NO":"DEV4-199","STORE_CODE":"DEV4","VEHICLE_NUMBER":"B 1988 BBR","DETAIL":[{"PRODUCT_CODE":"AC20002","SHIPMENT_QTY":26.00000000,"UOM":"TRY","PRICE":57000.00000000,"BATCH":"260830-26090501","EXPIRY_DATE":"2026-09-10"},{"PRODUCT_CODE":"AC20003","SHIPMENT_QTY":15.00000000,"UOM":"TRY","PRICE":60800.00000000,"BATCH":"260830-26090501","EXPIRY_DATE":"2026-09-10"}]}
'@

if ($PayloadFile) {
    if (-not (Test-Path -LiteralPath $PayloadFile)) {
        throw "PayloadFile tidak ditemukan: $PayloadFile"
    }
    $RawPayload = Get-Content -LiteralPath $PayloadFile -Raw
    Write-Host "Payload dibaca dari $PayloadFile" -ForegroundColor DarkGray
} else {
    $RawPayload = $DefaultPayload
    Write-Host "Payload DN25 bawaan dipakai." -ForegroundColor DarkGray
}

# ------------------------------------------------------------------ login ---

$secure = Read-Host -Prompt "Password KACS untuk user '$Username'" -AsSecureString
$bstr   = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    $loginBody = @{ username = $Username; password = $plain } | ConvertTo-Json -Compress
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    Remove-Variable plain -ErrorAction SilentlyContinue
}

Write-Host "Login ke $LoginUrl ..." -ForegroundColor Cyan
try {
    $login = Invoke-RestMethod -Method Post -Uri $LoginUrl `
             -ContentType 'application/json' -Body $loginBody -TimeoutSec $TimeoutSec
} catch {
    throw "Login gagal: $($_.Exception.Message)"
} finally {
    Remove-Variable loginBody -ErrorAction SilentlyContinue
}

$Token = $login.data.token
if (-not $Token) { $Token = $login.token }
if (-not $Token) {
    throw "Login berhasil tapi token tidak ketemu. Response: $($login | ConvertTo-Json -Depth 6)"
}
Write-Host "Token diterima." -ForegroundColor Green

# ----------------------------------------------------------------- helper ---

function Send-Kacs {
    param(
        [Parameter(Mandatory)][string] $Json,
        [Parameter(Mandatory)][string] $Label
    )

    $bytes = [Text.Encoding]::UTF8.GetBytes($Json)
    $code  = 0
    $out   = ''

    try {
        $r = Invoke-WebRequest -Method Post -Uri $ShipmentUrl -UseBasicParsing `
             -Headers @{ Authorization = "Bearer $Token" } `
             -ContentType 'application/json' -Body $bytes -TimeoutSec $TimeoutSec
        $code = [int] $r.StatusCode
        $out  = $r.Content
    }
    catch {
        $resp = $_.Exception.Response
        if ($resp) {
            $code = [int] $resp.StatusCode
            if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
                $out = $_.ErrorDetails.Message
            } else {
                $reader = New-Object IO.StreamReader($resp.GetResponseStream())
                try { $out = $reader.ReadToEnd() } finally { $reader.Dispose() }
            }
        } else {
            $out = "TRANSPORT: $($_.Exception.Message)"
        }
    }

    $verdict = 'GAGAL'
    if ($code -eq 201 -and $out -match '"code"\s*:\s*200')  { $verdict = 'SUKSES' }
    elseif ($out -match '"code"\s*:\s*1010')                { $verdict = 'DUPLIKAT' }

    Write-Host ("  {0,-22} HTTP {1,-4} {2}" -f $Label, $code, $verdict) -ForegroundColor DarkGray

    [pscustomobject]@{
        Test    = $Label
        Http    = $code
        Verdict = $verdict
        Body    = $out
    }
}

# --------------------------------------------------------------- varian ---

Write-Host ''
Write-Host 'Mengirim varian ke KACS:' -ForegroundColor Cyan

$hasil = New-Object System.Collections.Generic.List[object]

# Replay apa adanya. Harus mereproduksi 1009 yang sama seperti dari SyteLine.
$hasil.Add( (Send-Kacs -Json $RawPayload -Label 'replay apa adanya') )

# V1 - DN_NO numerik, qty dan price jadi bilangan bulat.
$o = $RawPayload | ConvertFrom-Json
$o.DN_NO = [int] $o.DN_NO
foreach ($d in $o.DETAIL) {
    $d.SHIPMENT_QTY = [int] $d.SHIPMENT_QTY
    $d.PRICE        = [int] $d.PRICE
}
$V1 = $o | ConvertTo-Json -Depth 6 -Compress
$hasil.Add( (Send-Kacs -Json $V1 -Label 'V1 numerik') )

# V2 - V1 + UOM numerik.
$o2 = $V1 | ConvertFrom-Json
foreach ($d in $o2.DETAIL) { $d.UOM = $Uom }
$V2 = $o2 | ConvertTo-Json -Depth 6 -Compress
$hasil.Add( (Send-Kacs -Json $V2 -Label "V2 UOM=$Uom") )

# V3 - V2 + WHS_CODE gaya KACS.
$o3 = $V2 | ConvertFrom-Json
$o3.WHS_CODE = $WhsCode
$V3 = $o3 | ConvertTo-Json -Depth 6 -Compress
$hasil.Add( (Send-Kacs -Json $V3 -Label "V3 WHS=$WhsCode") )

# ----------------------------------------------------------------- hasil ---

Write-Host ''
Write-Host 'Ringkasan:' -ForegroundColor Cyan
$hasil | Format-Table Test, Http, Verdict -AutoSize

Write-Host 'Response lengkap:' -ForegroundColor Cyan
$hasil | Format-List Test, Http, Body

Write-Host ''
Write-Host 'Varian pertama yang berubah dari 1009 menandai field penyebabnya.' -ForegroundColor Yellow
Write-Host 'DN yang sama aman diulang selama masih 1009 - KACS belum menyimpan apa pun.' -ForegroundColor Yellow

# Simpan untuk dilampirkan ke tests/evidence kalau perlu.
$stamp   = Get-Date -Format 'yyyyMMdd-HHmmss'
$outFile = Join-Path $PSScriptRoot "kacs-payload-probe-$stamp.json"
$hasil | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $outFile -Encoding UTF8
Write-Host "Hasil disimpan: $outFile" -ForegroundColor DarkGray
