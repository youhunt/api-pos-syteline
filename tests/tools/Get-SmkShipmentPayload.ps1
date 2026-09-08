<#
.SYNOPSIS
    Mengambil payload Shipment SMK069 dari SyteLine lewat Mongoose REST dan
    menyimpannya ke file, utuh.

.DESCRIPTION
    Query Execution memotong kolom NVARCHAR(MAX) di grid, jadi RequestJson tidak
    bisa disalin lengkap dari sana. REST tidak punya batasan itu.

    Dua jalur, dicoba berurutan:

      1. BACA log outbound - ue_SMK069_shipment_api_log_mst lewat IDO
         ue_SMK069ShipmentTransport. Ini byte yang benar-benar pernah dikirim
         ke KACS. Tidak mengubah apa pun.

      2. Kalau tidak ada baris log, panggil SMK069PrepareShipmentSendSp dan
         ambil PayloadJson dari output-nya. Ini membuat baris log baru berstatus
         N; gunakan -NoPrepare kalau tidak mau.

    Payload ditulis apa adanya, byte per byte. Skrip tidak pernah mengurai atau
    menyusun ulang isinya.

.EXAMPLE
    .\Get-SmkShipmentPayload.ps1 -DnNo 25 -OutFile ..\payloads\dn25-actual.json

.EXAMPLE
    .\Get-SmkShipmentPayload.ps1 -DnNo 25 -OutFile ..\payloads\dn25-actual.json -NoPrepare
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [long]   $DnNo,

    [Parameter(Mandatory)]
    [string] $OutFile,

    [string] $MgrestBase = 'https://csi10a.erpsl.ne1.inforcloudsuite.com/IDORequestService/MGRESTService.svc',
    [string] $IdoBase    = 'https://csi10a.erpsl.ne1.inforcloudsuite.com/IDORequestService/ido',
    [string] $Config     = 'QVB73V7ZQ357MR86_TRN_TRN_TBB',
    [string] $Ido        = 'ue_SMK069ShipmentTransport',

    [switch] $NoPrepare,
    [int]    $TimeoutSec = 60
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ------------------------------------------------------------------ token ---

$UserId = Read-Host -Prompt 'Mongoose userid'
$secure = Read-Host -Prompt "Password Mongoose untuk '$UserId'" -AsSecureString
$bstr   = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    Write-Host 'Mengambil security token ...' -ForegroundColor Cyan
    $tokenResp = Invoke-RestMethod -Method Get `
                 -Uri "$MgrestBase/json/token/$Config" `
                 -Headers @{ userid = $UserId; password = $plain } `
                 -TimeoutSec $TimeoutSec
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    Remove-Variable plain -ErrorAction SilentlyContinue
}

$Token = $tokenResp.Token
if (-not $Token) { throw "Token tidak ditemukan. Respons: $($tokenResp | ConvertTo-Json -Depth 5)" }
Write-Host 'Token diterima.' -ForegroundColor Green

$Headers = @{ Authorization = $Token }

# ----------------------------------------------------------------- helper ---

function Find-Property {
    <#
        Mencari properti bernama $Name di mana pun dalam struktur respons,
        tanpa mengasumsikan bentuk pembungkus MGREST.
    #>
    param($Node, [string] $Name)

    if ($null -eq $Node) { return $null }

    if ($Node -is [string]) { return $null }

    if ($Node -is [System.Collections.IEnumerable]) {
        foreach ($item in $Node) {
            $hit = Find-Property -Node $item -Name $Name
            if ($hit) { return $hit }
        }
        return $null
    }

    if ($Node.PSObject -and $Node.PSObject.Properties) {
        foreach ($p in $Node.PSObject.Properties) {
            if ($p.Name -eq $Name -and $p.Value -is [string] -and $p.Value.Length -gt 0) {
                return $p.Value
            }
        }
        foreach ($p in $Node.PSObject.Properties) {
            $hit = Find-Property -Node $p.Value -Name $Name
            if ($hit) { return $hit }
        }
    }

    return $null
}

$Payload = $null

# --------------------------------------------------- 1. baca log outbound ---

Write-Host "Membaca log outbound untuk DN $DnNo ..." -ForegroundColor Cyan

$filter = [uri]::EscapeDataString("ShipmentId = $DnNo")
$readUrl = "$MgrestBase/json/$Ido/adv?props=ShipmentId,RequestDate,ProcessStatus,RequestJson&filter=$filter&orderby=RequestDate%20DESC&recordcap=1"

try {
    $log = Invoke-RestMethod -Method Get -Uri $readUrl -Headers $Headers -TimeoutSec $TimeoutSec
    $Payload = Find-Property -Node $log -Name 'RequestJson'
}
catch {
    Write-Host "  gagal membaca log: $($_.Exception.Message)" -ForegroundColor DarkYellow
}

if ($Payload) {
    Write-Host '  payload diambil dari log outbound (byte yang benar-benar dikirim).' -ForegroundColor Green
}
else {
    Write-Host '  tidak ada RequestJson di log.' -ForegroundColor DarkYellow

    if ($NoPrepare) {
        throw "Tidak ada payload di log dan -NoPrepare aktif. Jalankan tanpa -NoPrepare untuk memanggil Prepare."
    }

    # --------------------------------------------------- 2. panggil Prepare ---

    Write-Host "Memanggil SMK069PrepareShipmentSendSp untuk DN $DnNo ..." -ForegroundColor Cyan
    Write-Host '  catatan: ini membuat baris log baru berstatus N.' -ForegroundColor DarkGray

    $body = ConvertTo-Json @($DnNo, $null, $null, $null, $null, $null) -Compress

    $prep = Invoke-RestMethod -Method Post `
            -Uri "$IdoBase/invoke/$Ido`?method=SMK069PrepareShipmentSendSp" `
            -Headers $Headers -ContentType 'application/json' `
            -Body $body -TimeoutSec $TimeoutSec

    # Urutan parameter SP: DN_No, EndpointUrl, LogRowPointer, PayloadJson, Success, Infobar
    if ($prep.Parameters -and $prep.Parameters.Count -ge 6) {
        $Payload = $prep.Parameters[3]
        Write-Host "  Success=$($prep.Parameters[4]); Infobar=$($prep.Parameters[5])" -ForegroundColor DarkGray
    }

    if (-not $Payload) {
        throw "Prepare tidak mengembalikan PayloadJson. Respons: $($prep | ConvertTo-Json -Depth 6)"
    }

    Write-Host '  payload diambil dari Prepare.' -ForegroundColor Green
}

# ------------------------------------------------------------------ tulis ---

$dir = Split-Path -Parent $OutFile
if ($dir -and -not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

# Tulis tanpa BOM, tanpa newline tambahan, tanpa mengurai isinya.
[IO.File]::WriteAllText(
    (Resolve-Path -LiteralPath $dir).Path + '\' + (Split-Path -Leaf $OutFile),
    $Payload,
    (New-Object Text.UTF8Encoding($false))
)

Write-Host ''
Write-Host "Tersimpan : $OutFile" -ForegroundColor Green
Write-Host "Panjang   : $($Payload.Length) karakter"

try {
    $probe = $Payload | ConvertFrom-Json
    $detail = if ($probe.DETAIL) { $probe.DETAIL.Count } else { 0 }
    Write-Host "JSON valid: ya; DN_NO=$($probe.DN_NO); DETAIL=$detail baris" -ForegroundColor Green
}
catch {
    Write-Host "JSON valid: TIDAK - $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Kemungkinan payload terpotong di sumbernya. Periksa isi file.' -ForegroundColor Red
}

Write-Host ''
Write-Host 'Langkah berikutnya:' -ForegroundColor Cyan
Write-Host "  .\Test-KacsShapeProbe.ps1 -PayloadFile $OutFile"
