<# 
.SYNOPSIS
    Unified system maintenance and application management script.

.DESCRIPTION
    Provides DISM/SFC/Defender checks, Windows Update, and package
    management via winget or Chocolatey. Supports interactive menu
    or parameter-based execution. Logs all output to a timestamped file.

.NOTES
    Run this script with administrator privileges.
#>

[CmdletBinding()]
param(
    [switch]$SkipDISM,
    [switch]$SkipSFC,
    [switch]$SkipDefenderScan,
    [switch]$SkipUpdates
)

# ---------------------------------- Initialization ---------------------------------- #

function Start-Logging {
    $global:LogDir = "$env:USERPROFILE\Desktop\MaintenanceLogs"
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory $LogDir | Out-Null
    }
    $global:LogFile = Join-Path $LogDir ("Maintenance_{0:yyyy-MM-dd_HH-mm-ss}.log" -f (Get-Date))
    Start-Transcript -Path $LogFile -IncludeInvocationHeader
}

function Ensure-Elevation {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
             ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "Please run this script as Administrator!"
        exit 1
    }
}

# ---------------------------------- Maintenance ------------------------------------- #

function Run-DISM {
    Write-Host "Running DISM..." -ForegroundColor Cyan
    try {
        DISM.exe /Online /Cleanup-Image /RestoreHealth
    } catch {
        Write-Warning "DISM failed: $_"
    }
}

function Run-SFC {
    Write-Host "Running SFC..." -ForegroundColor Cyan
    try {
        sfc.exe /scannow
    } catch {
        Write-Warning "SFC failed: $_"
    }
}

function Run-DefenderScan {
    Write-Host "Updating Defender definitions..." -ForegroundColor Cyan
    Update-MpSignature -ErrorAction SilentlyContinue
    Write-Host "Starting full Defender scan..." -ForegroundColor Cyan
    $job = Start-MpScan -ScanType FullScan -AsJob
    Wait-Job $job
}

function Run-WindowsUpdate {
    Write-Host "Checking Windows Update..." -ForegroundColor Cyan
    Install-WindowsUpdate -AcceptAll -AutoReboot -ErrorAction SilentlyContinue
}

# -------------------------------- App Management ------------------------------------ #

function Check-PackageManager {
    param([string]$Manager)
    try {
        Get-Command $Manager -ErrorAction Stop | Out-Null
        $true
    } catch {
        $false
    }
}

function Install-PackageManager {
    param([string]$Manager)

    if ($Manager -eq "winget") {
        Write-Host "Opening Microsoft Store for winget installation..."
        Start-Process "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1"
    }
    elseif ($Manager -eq "choco") {
        Write-Host "Installing Chocolatey..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    }
}

function Update-AllApps {
    if (Check-PackageManager -Manager "winget") {
        Write-Host "Updating applications with winget..." -ForegroundColor Cyan
        winget upgrade --all
    } else {
        Write-Warning "winget not available."
    }
}

function Install-Programs {
    param([string[]]$Programs)

    $packageManager = if (Check-PackageManager -Manager "winget") { "winget" }
                      elseif (Check-PackageManager -Manager "choco") { "choco" }
                      else { $null }

    if (-not $packageManager) {
        Write-Host "No package manager detected."
        return
    }

    foreach ($program in $Programs) {
        if ($packageManager -eq "winget") {
            winget install --id $program --accept-package-agreements --accept-source-agreements
        } else {
            choco install $program -y
        }
    }
}

# ------------------------------------- Main ----------------------------------------- #

Ensure-Elevation
Start-Logging

try {
    if (-not $SkipDISM)         { Run-DISM }
    if (-not $SkipSFC)          { Run-SFC }
    if (-not $SkipDefenderScan) { Run-DefenderScan }
    if (-not $SkipUpdates)      { Run-WindowsUpdate }

    $resp = Read-Host "Update all installed apps now? (Y/N)"
    if ($resp -match '^[Yy]$') { Update-AllApps }
}
finally {
    Stop-Transcript
    Write-Host "Log saved to $LogFile" -ForegroundColor Green
}
