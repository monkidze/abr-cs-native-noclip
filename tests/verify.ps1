param([Parameter(Mandatory=$true)][string]$OriginalEngine, [Parameter(Mandatory=$true)][string]$TestRoot)
$ErrorActionPreference = 'Stop'
$Repo = Split-Path $PSScriptRoot
$Original = '8B19B8DC3E2BAF3CC105D9A1069EB512996BC1B3161669917E56A4164D4C9B8F'
$Patched = '182CB3161F58AD90B01F53F6E25CC8BBAA0B07F9F4CD0C483D177C9EA95B8A40'
if ((Get-FileHash -LiteralPath $OriginalEngine).Hash -ne $Original) { throw 'Supply the original supported ABR executable.' }
$Trial = Join-Path $TestRoot ('noclip-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path "$Trial\bin","$Trial\_appdata_" | Out-Null
$Exe = "$Trial\bin\xrEngine.exe"
$Cfg = "$Trial\_appdata_\user.ltx"
$Enc = [Text.Encoding]::GetEncoding(28591)
$Text = "; legacy comment: " + [char]0xE9 + "`n" + "default_controls`nbind forward kW`n"
function Reset-Fixture {
    Copy-Item -LiteralPath $OriginalEngine -Destination $Exe -Force
    [IO.File]::WriteAllBytes($Cfg,$Enc.GetBytes($Text))
}
function Run-Tool([string]$Name,[int]$Expected=0) {
    $Output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Repo "$Name.ps1") -GamePath $Trial 2>&1
    if ($LASTEXITCODE -ne $Expected) { throw "$Name returned $LASTEXITCODE : $Output" }
}
function Assert([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
Reset-Fixture
$Before = (Get-FileHash $Cfg).Hash
Run-Tool install
Assert ((Get-FileHash $Exe).Hash -eq $Patched) 'Install engine hash'
Assert ($Enc.GetString([IO.File]::ReadAllBytes($Cfg)).StartsWith($Text)) 'Legacy bytes preserved'
$BackupCount = @(Get-ChildItem $Trial -Directory -Filter '_abr_noclip_backup_*').Count
Run-Tool install
Assert (@(Get-ChildItem $Trial -Directory -Filter '_abr_noclip_backup_*').Count -eq $BackupCount) 'Repeat install should not create backups'
Run-Tool uninstall
Assert ((Get-FileHash $Exe).Hash -eq $Original -and (Get-FileHash $Cfg).Hash -eq $Before) 'Exact round trip'
Write-Host 'PASS: installation, byte preservation, repeat install and uninstall'

Reset-Fixture
[IO.File]::AppendAllText($Cfg,"bind_console screenshot kF2`n",$Enc)
$Before = (Get-FileHash $Cfg).Hash
Run-Tool install 1
Assert ((Get-FileHash $Exe).Hash -eq $Original -and (Get-FileHash $Cfg).Hash -eq $Before) 'F2 conflict must not mutate files'
Write-Host 'PASS: F2 conflict rejection'

Reset-Fixture
[IO.File]::WriteAllBytes($Exe,[byte[]](1,2,3,4))
$Before = (Get-FileHash $Exe).Hash
Run-Tool install 1
Run-Tool uninstall 1
Assert ((Get-FileHash $Exe).Hash -eq $Before) 'Unsupported engine untouched'
Write-Host 'PASS: unsupported engine rejection'

Reset-Fixture
[byte[]]$Damaged = [IO.File]::ReadAllBytes($Exe)
$Damaged[0x41E1B] = 0x90
[IO.File]::WriteAllBytes($Exe,$Damaged)
$Before = (Get-FileHash $Exe).Hash
Run-Tool install 1
Assert ((Get-FileHash $Exe).Hash -eq $Before) 'Partial patch refused'
Write-Host 'PASS: tampered engine rejection'

Reset-Fixture
$Before = (Get-FileHash $Cfg).Hash
$Lock = [IO.File]::Open($Cfg,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
try { Run-Tool install 1 } finally { $Lock.Dispose() }
Assert ((Get-FileHash $Exe).Hash -eq $Original -and (Get-FileHash $Cfg).Hash -eq $Before) 'Install failure rollback'
Run-Tool install
$Before = (Get-FileHash $Cfg).Hash
$Lock = [IO.File]::Open($Cfg,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
try { Run-Tool uninstall 1 } finally { $Lock.Dispose() }
Assert ((Get-FileHash $Exe).Hash -eq $Patched -and (Get-FileHash $Cfg).Hash -eq $Before) 'Uninstall failure rollback'
Write-Host 'PASS: failed-write recovery in both directions'

Reset-Fixture
[IO.File]::AppendAllText($Cfg,"bind_console demo_record 1 kF2`nunbindall`n",$Enc)
Run-Tool install
Assert ($Enc.GetString([IO.File]::ReadAllBytes($Cfg)).EndsWith("unbindall`nbind_console demo_record 1 kF2`n")) 'Binding moved after reset'
Run-Tool uninstall
Write-Host 'PASS: binding repair after control reset'
Write-Host "All noclip checks passed. Private fixture retained at $Trial"
