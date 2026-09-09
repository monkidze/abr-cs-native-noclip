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
        throw "Clear Sky is running. Close the game and run this uninstaller again."
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

    $EngineHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $EnginePath).Hash
    if ($EngineHash -eq $PatchedEngineHash) {
        [byte[]]$EngineData = [IO.File]::ReadAllBytes($EnginePath)
        if (-not (Test-Bytes -Data $EngineData -Offset $PatchOffset -Expected $PatchedBytes)) {
            throw "The patched engine did not contain the expected bytes. No files were changed."
        }
        for ($index = 0; $index -lt $OriginalBytes.Length; $index++) {
            $EngineData[$PatchOffset + $index] = $OriginalBytes[$index]
        }
        [IO.File]::WriteAllBytes($EnginePath, $EngineData)
        if ((Get-FileHash -Algorithm SHA256 -LiteralPath $EnginePath).Hash -ne $OriginalEngineHash) {
            throw "Engine verification failed. Restore xrEngine.exe from the _abr_noclip_backup_* folder."
        }
    }
    elseif ($EngineHash -ne $OriginalEngineHash) {
        throw "This xrEngine.exe is not a recognized original or patched ABR build. No files were changed."
    }

    if (Test-Path -LiteralPath $UserConfigPath -PathType Leaf) {
        $ConfigText = [IO.File]::ReadAllText($UserConfigPath)
        $Lines = [regex]::Split($ConfigText, "\r?\n") | Where-Object {
            $_ -notmatch "^bind_console\s+demo_record\s+1\s+kF2\s*$"
        }
        $Utf8NoBom = [Text.UTF8Encoding]::new($false)
        [IO.File]::WriteAllText($UserConfigPath, (($Lines -join "`r`n").TrimEnd() + "`r`n"), $Utf8NoBom)
    }

    Write-Host "ABR Native Noclip removed successfully." -ForegroundColor Green
    Write-Host "Your _abr_noclip_backup_* folder was kept for safety."
}
catch {
    Write-Host ""
    Write-Host ("Uninstall failed: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
