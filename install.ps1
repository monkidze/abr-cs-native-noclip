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
$ChangesStarted = $false

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
    $GamePath = (Resolve-Path -LiteralPath $GamePath.Trim().Trim('"')).Path

    $EnginePath = Join-Path $GamePath "bin\xrEngine.exe"
    $UserConfigPath = Join-Path $GamePath "_appdata_\user.ltx"
    if (-not (Test-Path -LiteralPath $EnginePath -PathType Leaf)) {
        throw "Could not find bin\xrEngine.exe in '$GamePath'."
    }
    if (-not (Test-Path -LiteralPath $UserConfigPath -PathType Leaf)) {
        throw "Could not find _appdata_\user.ltx. Launch the game once, close it, and try again."
    }

    $EngineHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $EnginePath).Hash
    # Latin-1 maps every byte 1:1; editing ASCII commands preserves legacy
    # code pages, UTF-8 bytes, comments and existing line endings exactly.
    $Encoding = [Text.Encoding]::GetEncoding(28591)
    [byte[]]$ConfigBytes = [IO.File]::ReadAllBytes($UserConfigPath)
    if ($ConfigBytes -contains 0 -or ($ConfigBytes.Length -ge 2 -and $ConfigBytes[0] -in 254,255)) {
        throw 'UTF-16 or binary user.ltx is unsupported. No files were changed.'
    }
    $ConfigText = $Encoding.GetString($ConfigBytes)
    if ($ConfigText -match '(?im)^\s*(?:bind|bind_sec|bind_console)\s+.*\s+kF2\s*$' -and
        $ConfigText -match '(?im)^\s*(?:bind|bind_sec|bind_console)\s+(?!demo_record\s+1\s+kF2\s*$).*\s+kF2\s*$') {
        throw 'F2 is already assigned. Choose another key for that binding before installing. No files were changed.'
    }
    $OwnPattern = '(?im)^[\t ]*bind_console[\t ]+demo_record[\t ]+1[\t ]+kF2[\t ]*(?:\r?\n|$)'
    $OwnBindings = [regex]::Matches($ConfigText, $OwnPattern)
    $Resets = [regex]::Matches($ConfigText, '(?im)^[\t ]*(?:default_controls|unbindall|unbind_console[\t ]+kF2)[\t ]*(?:\r?\n|$)')
    $BindingPresent = $OwnBindings.Count -eq 1 -and ($Resets.Count -eq 0 -or $OwnBindings[0].Index -gt $Resets[$Resets.Count - 1].Index)

    if ($EngineHash -eq $PatchedEngineHash -and $BindingPresent) {
        Write-Host "Native noclip is already installed." -ForegroundColor Green
        exit 0
    }
    if ($EngineHash -ne $OriginalEngineHash -and $EngineHash -ne $PatchedEngineHash) {
        throw "This xrEngine.exe is not the supported ABR CS MOD Final build. No files were changed."
    }

    $BackupPath = Join-Path $GamePath ("_abr_noclip_backup_" + (Get-Date -Format "yyyyMMdd_HHmmss") + '_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path (Join-Path $BackupPath "bin"), (Join-Path $BackupPath "_appdata_") -Force | Out-Null
    Copy-Item -LiteralPath $EnginePath -Destination (Join-Path $BackupPath "bin\xrEngine.exe")
    Copy-Item -LiteralPath $UserConfigPath -Destination (Join-Path $BackupPath "_appdata_\user.ltx")
    if ((Get-FileHash -LiteralPath (Join-Path $BackupPath 'bin\xrEngine.exe')).Hash -ne $EngineHash -or
        (Get-FileHash -LiteralPath (Join-Path $BackupPath '_appdata_\user.ltx')).Hash -ne (Get-FileHash -LiteralPath $UserConfigPath).Hash) {
        throw 'Backup verification failed. No files were changed.'
    }
    $ChangesStarted = $true

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

    # Put the binding after all reset/default commands, not before them.
    if (-not $BindingPresent) {
        $ConfigText = [regex]::Replace($ConfigText, $OwnPattern, '')
        $Newline = if ($ConfigText.Contains("`r`n")) { "`r`n" } else { "`n" }
        $Separator = if ($ConfigText.Length -gt 0 -and -not $ConfigText.EndsWith("`n")) { $Newline } else { '' }
        [IO.File]::WriteAllBytes($UserConfigPath, $Encoding.GetBytes($ConfigText + $Separator + $Binding + $Newline))
    }

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
    if ($ChangesStarted) {
        foreach ($Relative in @('bin\xrEngine.exe', '_appdata_\user.ltx')) {
            try {
                $Saved = Join-Path $BackupPath $Relative
                $Target = Join-Path $GamePath $Relative
                if ((Get-FileHash -LiteralPath $Saved).Hash -ne (Get-FileHash -LiteralPath $Target).Hash) {
                    Copy-Item -LiteralPath $Saved -Destination $Target -Force
                    if ((Get-FileHash -LiteralPath $Saved).Hash -ne (Get-FileHash -LiteralPath $Target).Hash) { throw 'Hash mismatch' }
                }
            } catch { Write-Host "Restore $Relative manually from $BackupPath : $_" -ForegroundColor Red }
        }
    }
    Write-Host ""
    Write-Host ("Installation failed: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
