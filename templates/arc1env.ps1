# ARC-1 multi-system helper (Windows / PowerShell)
# Install: dot-source from your $PROFILE:   . "$HOME\.arc1\arc1env.ps1"
#
# Layout:
#   ~/.arc1/
#     arc1env.ps1        <- this file
#     systems/<sid>.env  <- connection only (URL, client, user, flags) — NEVER the password
#     secrets/<sid>.sec  <- password encrypted with DPAPI (per-user, per-machine)

$script:Arc1Root = Join-Path $HOME '.arc1'

function Get-Arc1Systems {
    Get-ChildItem (Join-Path $script:Arc1Root 'systems') -Filter '*.env' |
        Where-Object { $_.BaseName -ne '_template' } |
        ForEach-Object { $_.BaseName }
}

function Set-Arc1Secret {
    param([Parameter(Mandatory)][string]$System)
    $secDir = Join-Path $script:Arc1Root 'secrets'
    if (-not (Test-Path $secDir)) { New-Item -ItemType Directory -Path $secDir | Out-Null }
    $sec = Read-Host "SAP password for '$System'" -AsSecureString
    # ConvertFrom-SecureString = DPAPI: only YOUR user on THIS machine can decrypt it.
    $sec | ConvertFrom-SecureString | Set-Content -Path (Join-Path $secDir "$System.sec") -Encoding ascii
    Write-Host "Password for '$System' stored (DPAPI-encrypted)." -ForegroundColor Green
}

function Use-Arc1 {
    param([Parameter(Mandatory)][string]$System)
    $envFile = Join-Path $script:Arc1Root "systems\$System.env"
    if (-not (Test-Path $envFile)) {
        Write-Host "System '$System' not found. Available: $((Get-Arc1Systems) -join ', ')" -ForegroundColor Red
        return
    }
    # clear any previous SAP_* so systems never bleed into each other
    Get-ChildItem Env: | Where-Object { $_.Name -like 'SAP_*' } | ForEach-Object { Remove-Item "Env:$($_.Name)" }
    # load the system's .env
    Get-Content $envFile | Where-Object { $_ -match '^\s*[^#].*=' } | ForEach-Object {
        $k, $v = $_ -split '=', 2
        Set-Item "Env:$($k.Trim())" $v.Trim()
    }
    # load the password (if stored)
    $secFile = Join-Path $script:Arc1Root "secrets\$System.sec"
    if (Test-Path $secFile) {
        $sec  = Get-Content $secFile | ConvertTo-SecureString
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
        $env:SAP_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        Write-Host "ARC-1 -> '$System'  ($env:SAP_URL, client $env:SAP_CLIENT)  [password OK]" -ForegroundColor Cyan
    } else {
        Write-Host "ARC-1 -> '$System'  ($env:SAP_URL, client $env:SAP_CLIENT)  [NO password - run: Set-Arc1Secret $System]" -ForegroundColor Yellow
    }
}

Set-Alias arc1use Use-Arc1
