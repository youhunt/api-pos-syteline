<#
.SYNOPSIS
    Bisecting terbalik: berangkat dari payload yang TERBUKTI diterima KACS,
    lalu ganti satu field ke nilai SyteLine tiap percobaan.

.DESCRIPTION
    Percobaan sebelumnya berangkat dari payload yang gagal dan menebak nilai
    penggantinya - empat varian, empat kali 1009 yang identik, nol informasi.

    Dengan satu payload yang diterima sebagai titik awal, arahnya bisa dibalik
    dan hasilnya pasti konvergen: ganti satu field, kirim, lihat apakah masih
    201. Field pertama yang menjatuhkannya ke 1009 adalah penyebabnya.

    Skrip membandingkan sendiri kedua file dan hanya menguji field yang memang
    berbeda - termasuk field di dalam DETAIL. Tidak ada nilai yang dikarang.

.PARAMETER BaselineFile
    Payload yang diterima KACS (HTTP 201, code 200). Ambil dari contoh dokumen
    KACS atau dari request Postman yang barusan berhasil.

.PARAMETER TargetFile
    Payload keluaran SyteLine, mis. hasil Get-SmkShipmentPayload.ps1.

.PARAMETER DnPrefix
    Awalan DN_NO untuk tiap percobaan. Setiap kiriman yang sukses TERSIMPAN di
    KACS UAT, jadi tiap percobaan wajib memakai DN_NO yang belum pernah dipakai,
    kalau tidak akan tertolak sebagai duplikat (code 1010).

.EXAMPLE
    .\Test-KacsReverseBisect.ps1 `
        -BaselineFile ..\payloads\kacs-accepted-sample.json `
        -TargetFile   ..\payloads\dn25-actual.json `
        -DnPrefix     DNPRB0907

.NOTES
    PERINGATAN: setiap percobaan yang menghasilkan 201 MENYIMPAN satu DN baru di
    KACS UAT. Skrip menampilkan jumlah percobaan dan meminta konfirmasi sebelum
    mengirim apa pun. Beri tahu tim KACS kalau UAT mereka tidak boleh terisi
    data uji.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $BaselineFile,
    [Parameter(Mandatory)][string] $TargetFile,
    [Parameter(Mandatory)][string] $DnPrefix,

    [string] $BaseUrl    = 'https://api-uat.pizzahut.co.id',
    [string] $Username   = 'kacs',
    [int]    $TimeoutSec = 60
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$LoginUrl    = "$BaseUrl/service-auth/login-once"
$ShipmentUrl = "$BaseUrl/inventory-phi/v1/kacs_dn"

foreach ($f in @($BaselineFile, $TargetFile)) {
    if (-not (Test-Path -LiteralPath $f)) { throw "File tidak ditemukan: $f" }
}

$BaseObj   = (Get-Content -LiteralPath $BaselineFile -Raw) | ConvertFrom-Json
$TargetObj = (Get-Content -LiteralPath $TargetFile   -Raw) | ConvertFrom-Json

# Contoh yang diterima mungkin masih berupa respons lengkap; ambil .data bila ada.
if ($BaseObj.PSObject.Properties.Name -contains 'data' -and $BaseObj.data) {
    Write-Host 'Baseline berbentuk respons; mengambil bagian .data' -ForegroundColor DarkGray
    $BaseObj = $BaseObj.data
}

# Buang field yang dihasilkan server, bukan bagian dari request.
foreach ($srv in @('client_uuid','uuid','is_active','is_delete','is_send_to_pos',
                   'created_at','updated_at','created_by','updated_by')) {
    if ($BaseObj.PSObject.Properties.Name -contains $srv) {
        $BaseObj.PSObject.Properties.Remove($srv)
    }
}

function Copy-Json { param($o) ($o | ConvertTo-Json -Depth 10 -Compress) | ConvertFrom-Json }

# ------------------------------------------------------ cari field berbeda ---

$headerFields = @()
foreach ($p in $BaseObj.PSObject.Properties) {
    if ($p.Name -eq 'DETAIL') { continue }
    if ($TargetObj.PSObject.Properties.Name -notcontains $p.Name) { continue }
    $bv = $BaseObj.$($p.Name)
    $tv = $TargetObj.$($p.Name)
    if ("$bv" -cne "$tv") {
        $headerFields += [pscustomobject]@{ Field = $p.Name; From = $bv; To = $tv }
    }
}

$detailFields = @()
if ($BaseObj.DETAIL -and $TargetObj.DETAIL) {
    $bd = $BaseObj.DETAIL[0]
    $td = $TargetObj.DETAIL[0]
    foreach ($p in $bd.PSObject.Properties) {
        if ($td.PSObject.Properties.Name -notcontains $p.Name) { continue }
        if ("$($bd.$($p.Name))" -cne "$($td.$($p.Name))") {
            $detailFields += [pscustomobject]@{ Field = $p.Name; From = $bd.$($p.Name); To = $td.$($p.Name) }
        }
    }
}

Write-Host ''
Write-Host 'Field yang berbeda antara baseline dan target:' -ForegroundColor Cyan
$headerFields | Format-Table @{n='Lokasi';e={'header'}}, Field, From, To -AutoSize
$detailFields | Format-Table @{n='Lokasi';e={'DETAIL'}}, Field, From, To -AutoSize

$total = 1 + $headerFields.Count + $detailFields.Count
Write-Host "Total percobaan: $total (1 kontrol + $($headerFields.Count) header + $($detailFields.Count) detail)" -ForegroundColor Yellow
Write-Host "Setiap percobaan yang sukses MENYIMPAN satu DN baru di KACS UAT." -ForegroundColor Yellow
$ok = Read-Host 'Lanjutkan? (ketik YA)'
if ($ok -cne 'YA') { Write-Host 'Dibatalkan.'; return }

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

$login = Invoke-RestMethod -Method Post -Uri $LoginUrl -ContentType 'application/json' `
         -Body $loginBody -TimeoutSec $TimeoutSec
Remove-Variable loginBody -ErrorAction SilentlyContinue

$Token = $login.data.token; if (-not $Token) { $Token = $login.token }
if (-not $Token) { throw 'Token tidak ditemukan pada respons login.' }
Write-Host 'Token diterima.' -ForegroundColor Green

# ----------------------------------------------------------------- helper ---

$script:seq = 0

function Send-Variant {
    param([Parameter(Mandatory)]$Obj, [Parameter(Mandatory)][string]$Label, [switch]$KeepDn)

    if (-not $KeepDn) {
        $script:seq++
        $Obj.DN_NO = "$DnPrefix{0:D2}" -f $script:seq
    }

    $json  = $Obj | ConvertTo-Json -Depth 10 -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    $code  = 0; $out = ''

    try {
        $r    = Invoke-WebRequest -Method Post -Uri $ShipmentUrl -UseBasicParsing `
                -Headers @{ Authorization = "Bearer $Token" } `
                -ContentType 'application/json' -Body $bytes -TimeoutSec $TimeoutSec
        $code = [int]$r.StatusCode; $out = $r.Content
    }
    catch {
        $resp = $_.Exception.Response
        if ($resp) {
            $code = [int]$resp.StatusCode
            $out  = if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $_.ErrorDetails.Message }
                    else {
                        $rd = New-Object IO.StreamReader($resp.GetResponseStream())
                        try { $rd.ReadToEnd() } finally { $rd.Dispose() }
                    }
        } else { $out = "TRANSPORT: $($_.Exception.Message)" }
    }

    $biz = if ($out -match '"code"\s*:\s*(\d+)') { $Matches[1] } else { $null }
    $verdict = switch ($biz) { '200' { 'DITERIMA' } '1010' { 'DUPLIKAT' } default { 'DITOLAK' } }

    $color = if ($verdict -eq 'DITERIMA') { 'Green' } else { 'Red' }
    Write-Host ("  {0,-34} HTTP {1,-5} code={2,-6} {3}" -f $Label, $code, $biz, $verdict) -ForegroundColor $color

    [pscustomobject]@{
        Test = $Label; DnNo = $Obj.DN_NO; Http = $code; Code = $biz; Verdict = $verdict; Body = $out
    }
}

# ---------------------------------------------------------------- jalankan ---

Write-Host ''
Write-Host 'Menjalankan bisecting terbalik:' -ForegroundColor Cyan

$hasil = New-Object System.Collections.Generic.List[object]

# Kontrol: baseline apa adanya, hanya DN_NO yang baru.
# Kalau ini saja sudah ditolak, baseline atau kredensialnya bermasalah - berhenti.
$ctl = Send-Variant -Obj (Copy-Json $BaseObj) -Label 'KONTROL baseline'
$hasil.Add($ctl)

if ($ctl.Verdict -ne 'DITERIMA') {
    Write-Host ''
    Write-Host 'KONTROL GAGAL. Baseline sendiri tidak diterima, jadi hasil percobaan' -ForegroundColor Red
    Write-Host 'berikutnya tidak akan berarti apa-apa. Periksa isi BaselineFile:' -ForegroundColor Red
    Write-Host 'harus payload REQUEST yang diterima, bukan respons, dan tanpa field' -ForegroundColor Red
    Write-Host 'buatan server. Respons kontrol:' -ForegroundColor Red
    Write-Host $ctl.Body
    return
}

foreach ($f in $headerFields) {
    $o = Copy-Json $BaseObj
    $o.$($f.Field) = $TargetObj.$($f.Field)
    $keep = ($f.Field -eq 'DN_NO')
    $hasil.Add( (Send-Variant -Obj $o -Label ("header {0} -> {1}" -f $f.Field, $f.To) -KeepDn:$keep) )
}

foreach ($f in $detailFields) {
    $o = Copy-Json $BaseObj
    foreach ($row in $o.DETAIL) { $row.$($f.Field) = $TargetObj.DETAIL[0].$($f.Field) }
    $hasil.Add( (Send-Variant -Obj $o -Label ("DETAIL {0} -> {1}" -f $f.Field, $f.To)) )
}

# --------------------------------------------------------------- kesimpulan ---

Write-Host ''
Write-Host 'Ringkasan:' -ForegroundColor Cyan
$hasil | Format-Table Test, DnNo, Http, Code, Verdict -AutoSize

$penyebab = $hasil | Where-Object { $_.Test -ne 'KONTROL baseline' -and $_.Verdict -eq 'DITOLAK' }

Write-Host ''
if ($penyebab.Count -eq 0) {
    Write-Host 'Tidak ada satu pun field yang menjatuhkan baseline.' -ForegroundColor Yellow
    Write-Host 'Berarti penyebabnya bukan nilai field tunggal, melainkan kombinasi' -ForegroundColor Yellow
    Write-Host 'atau struktur. Jalankan lagi dengan dua field diganti sekaligus.' -ForegroundColor Yellow
} else {
    Write-Host "FIELD PENYEBAB ($($penyebab.Count)):" -ForegroundColor Green
    $penyebab | ForEach-Object { Write-Host ("  - " + $_.Test) -ForegroundColor Green }
    Write-Host ''
    Write-Host 'Perbaikannya di SMK069_ShipmentAPI_mst dan SMK069BuildShipmentJsonSp,' -ForegroundColor Green
    Write-Host 'bukan di extension class.' -ForegroundColor Green
}

$stamp   = Get-Date -Format 'yyyyMMdd-HHmmss'
$outFile = Join-Path $PSScriptRoot "kacs-reverse-bisect-$stamp.json"
$hasil | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $outFile -Encoding UTF8
Write-Host ''
Write-Host "Hasil disimpan: $outFile" -ForegroundColor DarkGray
