[CmdletBinding()]
param(
    [string]$GamePath
)

$ErrorActionPreference = "Stop"
$OriginalEngineHash = "8B19B8DC3E2BAF3CC105D9A1069EB512996BC1B3161669917E56A4164D4C9B8F"
$PatchedEngineHash = "182CB3161F58AD90B01F53F6E25CC8BBAA0B07F9F4CD0C483D177C9EA95B8A40"
$PatchOffset = 0x41E1B
[byte[]]$OriginalBytes = 0x0F, 0x84, 0xC7, 0x00, 0x00, 0x00
[byte[]]$PatchedBytes = 0x90, 0x90, 0x90, 0x90, 0x90, 0x90
$Binding = "bind_console demo_record 1 kF2"

function Test-Bytes {
    param([byte[]]$Data, [int]$Offset, [byte[]]$Expected)
    if ($Offset -lt 0 -or ($Offset + $Expected.Length) -gt $Data.Length) {
        return $false
    }
    for ($index = 0; $index -lt $Expected.Length; $index++) {
        if ($Data[$Offset + $index] -ne $Expected[$index]) {
            return $false
        }
    }
    return $true
}

try {
    if (Get-Process -Name "xrEngine" -ErrorAction SilentlyContinue) {
        throw "Clear Sky is running. Close the game and run this installer again."
    }

    if ([string]::IsNullOrWhiteSpace($GamePath)) {
        $GamePath = Read-Host "Enter your STALKER Clear Sky folder"
    }
    $GamePath = (Resolve-Path -LiteralPath $GamePath).Path

    $EnginePath = Join-Path $GamePath "bin\xrEngine.exe"
    $UserConfigPath = Join-Path $GamePath "_appdata_\user.ltx"
    if (-not (Test-Path -LiteralPath $EnginePath -PathType Leaf)) {
        throw "Could not find bin\xrEngine.exe in '$GamePath'."
    }
    if (-not (Test-Path -LiteralPath $UserConfigPath -PathType Leaf)) {
        throw "Could not find _appdata_\user.ltx. Launch the game once, close it, and try again."
    }

    $EngineHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $EnginePath).Hash
    $ConfigText = [IO.File]::ReadAllText($UserConfigPath)
    $BindingPresent = $ConfigText -match "(?m)^bind_console\s+demo_record\s+1\s+kF2\s*$"

    if ($EngineHash -eq $PatchedEngineHash -and $BindingPresent) {
        Write-Host "Native noclip is already installed." -ForegroundColor Green
        exit 0
    }
    if ($EngineHash -ne $OriginalEngineHash -and $EngineHash -ne $PatchedEngineHash) {
        throw "This xrEngine.exe is not the supported ABR CS MOD Final build. No files were changed."
    }

    $BackupPath = Join-Path $GamePath ("_abr_noclip_backup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
    New-Item -ItemType Directory -Path (Join-Path $BackupPath "bin"), (Join-Path $BackupPath "_appdata_") -Force | Out-Null
    Copy-Item -LiteralPath $EnginePath -Destination (Join-Path $BackupPath "bin\xrEngine.exe")
    Copy-Item -LiteralPath $UserConfigPath -Destination (Join-Path $BackupPath "_appdata_\user.ltx")

    if ($EngineHash -eq $OriginalEngineHash) {
        [byte[]]$EngineData = [IO.File]::ReadAllBytes($EnginePath)
        if (-not (Test-Bytes -Data $EngineData -Offset $PatchOffset -Expected $OriginalBytes)) {
            throw "The engine hash matched, but the patch location did not. The backup is intact; installation stopped."
        }
        for ($index = 0; $index -lt $PatchedBytes.Length; $index++) {
            $EngineData[$PatchOffset + $index] = $PatchedBytes[$index]
        }
        [IO.File]::WriteAllBytes($EnginePath, $EngineData)
        $ResultHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $EnginePath).Hash
        if ($ResultHash -ne $PatchedEngineHash) {
            Copy-Item -LiteralPath (Join-Path $BackupPath "bin\xrEngine.exe") -Destination $EnginePath -Force
            throw "Engine verification failed. The original executable was restored."
        }
    }

    $Lines = [regex]::Split($ConfigText, "\r?\n")
    $NewLines = [Collections.Generic.List[string]]::new()
    $Inserted = $false
    foreach ($Line in $Lines) {
        if ($Line -match "^bind_console\s+.+\s+kF2\s*$") {
            continue
        }
        $NewLines.Add($Line)
        if (-not $Inserted -and $Line.Trim() -eq "default_controls") {
            $NewLines.Add($Binding)
            $Inserted = $true
        }
    }
    if (-not $Inserted) {
        $NewLines.Insert(0, $Binding)
    }
    $Utf8NoBom = [Text.UTF8Encoding]::new($false)
    [IO.File]::WriteAllText($UserConfigPath, (($NewLines -join "`r`n").TrimEnd() + "`r`n"), $Utf8NoBom)

    $FinalConfig = [IO.File]::ReadAllText($UserConfigPath)
    if ($FinalConfig -notmatch "(?m)^bind_console\s+demo_record\s+1\s+kF2\s*$") {
        Copy-Item -LiteralPath (Join-Path $BackupPath "_appdata_\user.ltx") -Destination $UserConfigPath -Force
        throw "Key binding verification failed. The original user configuration was restored."
    }

    Write-Host ""
    Write-Host "ABR Native Noclip installed successfully." -ForegroundColor Green
    Write-Host "Backup: $BackupPath"
    Write-Host ""
    Write-Host "F2: start free flight"
    Write-Host "Enter: move the actor to the camera and exit"
    Write-Host "Escape: cancel without moving the actor"
}
catch {
    Write-Host ""
    Write-Host ("Installation failed: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
