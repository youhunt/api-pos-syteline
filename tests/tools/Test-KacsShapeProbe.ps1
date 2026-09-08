<#
.SYNOPSIS
    Menguji BENTUK payload Shipment ke KACS UAT, bukan nilai field-nya.

.DESCRIPTION
    Setelah empat varian nilai (numerik, UOM, WHS_CODE) semuanya ditolak dengan
    1009 Invalid params yang identik, menebak nilai lain tidak ada gunanya.

    Skrip ini mengubah pertanyaannya: apakah 1009 itu bisa membedakan sesuatu?

    Ia mengirim payload yang bentuknya berbeda-beda jauh - object kosong, array
    pembungkus, JSON yang sama sekali bukan Shipment - lalu membandingkan
    responsnya. Hasilnya menentukan langkah berikutnya:

      - kalau SEMUA balasan identik 1009: validator KACS tidak memberi umpan
        balik apa pun, bisecting mustahil, satu-satunya jalan adalah contoh
        payload dari dokumen KACS.

      - kalau ADA yang berbeda: bentuk itulah petunjuknya, dan pencarian bisa
        dilanjutkan ke arah tersebut.

    Payload dasarnya dibaca dari file, bukan diketik ulang. Ambil dari
    ue_SMK069_shipment_api_log_mst.RequestJson - itu byte yang benar-benar
    dikirim SyteLine - atau dari tombol Preview JSON di form.

.EXAMPLE
    .\Test-KacsShapeProbe.ps1 -PayloadFile ..\payloads\dn25-actual.json

.NOTES
    Tidak ada satu pun probe di sini yang bisa membuat KACS menyimpan data:
    selama respons masih 1009, tidak ada yang tersimpan. Aman diulang.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $PayloadFile,

    [string] $BaseUrl    = 'https://api-uat.pizzahut.co.id',
    [string] $Username   = 'kacs',
    [int]    $TimeoutSec = 60
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$LoginUrl    = "$BaseUrl/service-auth/login-once"
$ShipmentUrl = "$BaseUrl/inventory-phi/v1/kacs_dn"

if (-not (Test-Path -LiteralPath $PayloadFile)) {
    throw "PayloadFile tidak ditemukan: $PayloadFile"
}

$Raw = (Get-Content -LiteralPath $PayloadFile -Raw).Trim()

try   { $null = $Raw | ConvertFrom-Json }
catch { throw "Isi $PayloadFile bukan JSON yang valid: $($_.Exception.Message)" }

Write-Host "Payload dasar : $PayloadFile ($($Raw.Length) karakter)" -ForegroundColor DarkGray

# ------------------------------------------------------------------ login ---

$secure = Read-Host -Prompt "Password KACS untuk user '$Username'" -AsSecureString
$bstr   = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
    $plain     = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    $loginBody = @{ username = $Username; password = $plain } | ConvertTo-Json -Compress
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    Remove-Variable plain -ErrorAction SilentlyContinue
}

Write-Host "Login ..." -ForegroundColor Cyan
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
if (-not $Token) { throw "Token tidak ditemukan pada respons login." }
Write-Host "Token diterima." -ForegroundColor Green

# ----------------------------------------------------------------- helper ---

function Send-Probe {
    param(
        [Parameter(Mandatory)][string] $Json,
        [Parameter(Mandatory)][string] $Label,
        [Parameter(Mandatory)][string] $Hipotesis
    )

    $bytes = [Text.Encoding]::UTF8.GetBytes($Json)
    $code  = 0
    $out   = ''

    try {
        $r    = Invoke-WebRequest -Method Post -Uri $ShipmentUrl -UseBasicParsing `
                -Headers @{ Authorization = "Bearer $Token" } `
                -ContentType 'application/json' -Body $bytes -TimeoutSec $TimeoutSec
        $code = [int] $r.StatusCode
        $out  = $r.Content
    }
    catch {
        $resp = $_.Exception.Response
        if ($resp) {
            $code = [int] $resp.StatusCode
            $out  = if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $_.ErrorDetails.Message }
                    else {
                        $reader = New-Object IO.StreamReader($resp.GetResponseStream())
                        try { $reader.ReadToEnd() } finally { $reader.Dispose() }
                    }
        } else {
            $out = "TRANSPORT: $($_.Exception.Message)"
        }
    }

    $bizCode = $null
    if ($out -match '"code"\s*:\s*(\d+)') { $bizCode = $Matches[1] }

    Write-Host ("  {0,-26} HTTP {1,-5} code={2}" -f $Label, $code, $bizCode) -ForegroundColor DarkGray

    [pscustomobject]@{
        Test      = $Label
        Hipotesis = $Hipotesis
        Http      = $code
        BizCode   = $bizCode
        Body      = $out
    }
}

# ---------------------------------------------------------------- probes ---

Write-Host ''
Write-Host 'Menguji bentuk payload:' -ForegroundColor Cyan

$hasil = New-Object System.Collections.Generic.List[object]

# P0 - baseline. Byte asli dari SyteLine, tanpa diubah sama sekali.
$hasil.Add( (Send-Probe -Json $Raw -Label 'P0 payload asli' `
    -Hipotesis 'Baseline. Harus mereproduksi 1009 yang sama seperti dari SyteLine.') )

# P1 - object kosong. Kalau validator memberi umpan balik, di sini tempatnya.
$hasil.Add( (Send-Probe -Json '{}' -Label 'P1 object kosong' `
    -Hipotesis 'Kalau balasannya sama persis dengan P0, validator tidak membedakan apa pun.') )

# P2 - JSON yang jelas bukan Shipment.
$hasil.Add( (Send-Probe -Json '{"halo":"dunia"}' -Label 'P2 json asing' `
    -Hipotesis 'Sama seperti P1. Dua-duanya identik dengan P0 = 1009 itu generik.') )

# P3 - dibungkus array. Banyak API terima list, bukan satu object.
$hasil.Add( (Send-Probe -Json ('[' + $Raw + ']') -Label 'P3 dibungkus array' `
    -Hipotesis 'Kalau berubah, KACS mengharapkan array of DN, bukan satu object.') )

# P4 - dibungkus properti data.
$hasil.Add( (Send-Probe -Json ('{"data":' + $Raw + '}') -Label 'P4 dibungkus data' `
    -Hipotesis 'Kalau berubah, payload bisnis harus berada di dalam amplop.') )

# P5 - hanya header, DETAIL dibuang.
$o5 = $Raw | ConvertFrom-Json
$o5.PSObject.Properties.Remove('DETAIL')
$hasil.Add( (Send-Probe -Json ($o5 | ConvertTo-Json -Depth 6 -Compress) -Label 'P5 tanpa DETAIL' `
    -Hipotesis 'Kalau berubah, masalahnya ada di dalam DETAIL, bukan di header.') )

# P6 - hanya DETAIL baris pertama.
$o6 = $Raw | ConvertFrom-Json
if ($o6.DETAIL -and $o6.DETAIL.Count -gt 1) {
    $o6.DETAIL = @($o6.DETAIL[0])
    $hasil.Add( (Send-Probe -Json ($o6 | ConvertTo-Json -Depth 6 -Compress) -Label 'P6 DETAIL satu baris' `
        -Hipotesis 'Kalau berubah, ada baris DETAIL tertentu yang bermasalah.') )
}

# --------------------------------------------------------------- kesimpulan ---

Write-Host ''
Write-Host 'Ringkasan:' -ForegroundColor Cyan
$hasil | Format-Table Test, Http, BizCode -AutoSize

Write-Host 'Response lengkap:' -ForegroundColor Cyan
$hasil | Format-List Test, Hipotesis, Http, Body

$distinct = ($hasil | ForEach-Object { "$($_.Http)|$($_.Body)" } | Sort-Object -Unique).Count

Write-Host ''
if ($distinct -le 1) {
    Write-Host 'SEMUA RESPONS IDENTIK.' -ForegroundColor Yellow
    Write-Host 'Object kosong, JSON asing, dan payload asli diperlakukan sama.' -ForegroundColor Yellow
    Write-Host '1009 tidak membawa informasi apa pun, jadi mencari lewat percobaan' -ForegroundColor Yellow
    Write-Host 'tidak akan pernah selesai. Minta contoh payload yang DITERIMA dari' -ForegroundColor Yellow
    Write-Host 'tim KACS, atau dokumen MF_SMK_API_SHIPMENT_REV_1.1.' -ForegroundColor Yellow
} else {
    Write-Host "ADA $distinct RESPONS BERBEDA - itu petunjuknya." -ForegroundColor Green
    Write-Host 'Lihat kolom Hipotesis pada probe yang responsnya menyimpang.' -ForegroundColor Green
}

$stamp   = Get-Date -Format 'yyyyMMdd-HHmmss'
$outFile = Join-Path $PSScriptRoot "kacs-shape-probe-$stamp.json"
$hasil | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $outFile -Encoding UTF8
Write-Host ''
Write-Host "Hasil disimpan: $outFile" -ForegroundColor DarkGray
