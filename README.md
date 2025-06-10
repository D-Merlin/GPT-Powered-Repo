# GPT-Powered-Repo

This repository contains small scripts generated with the help of ChatGPT. The
main utility at the moment is `UnifiedSystemMaintenance.ps1` which performs
common Windows maintenance tasks and optionally updates installed applications.

## UnifiedSystemMaintenance.ps1

`UnifiedSystemMaintenance.ps1` is a PowerShell script intended to run from an
elevated prompt. It combines DISM, SFC and Windows Defender checks with the
ability to install Windows updates and update applications via **winget** or
**Chocolatey**.

```
./UnifiedSystemMaintenance.ps1 [-SkipDISM] [-SkipSFC] [-SkipDefenderScan] [-SkipUpdates]
```

The script logs all output to `~/Desktop/MaintenanceLogs/` with a timestamped
file name. During execution you will be prompted to update applications using
the detected package manager. The `Run-WindowsUpdate` step relies on the
`PSWindowsUpdate` module, so ensure it is installed if you want automatic
Windows Update checks.

Feel free to adapt or extend the script for your own workflow.
