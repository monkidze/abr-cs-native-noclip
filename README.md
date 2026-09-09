# Native Noclip for ABR CS MOD Final

A small installer that enables the native X-Ray free-flight and actor-relocation mode in [ABR CS MOD Final](https://www.moddb.com/mods/abr-cs-mod) for **S.T.A.L.K.E.R.: Clear Sky**.

This is not a trainer and does not inject a DLL. It uses the engine's existing `demo_record` controller and enables the native Enter-to-relocate code that ABR's executable keeps behind an inactive runtime gate.

## Compatibility

- S.T.A.L.K.E.R.: Clear Sky 1.5.10
- ABR CS MOD Final
- Windows Steam installation
- Supported original `xrEngine.exe` SHA-256: `8B19B8DC3E2BAF3CC105D9A1069EB512996BC1B3161669917E56A4164D4C9B8F`

The installer stops safely without changing anything if the executable does not match the supported ABR build.

## Installation

1. Install and launch ABR CS MOD Final at least once.
2. Close the game completely.
3. Download and extract the latest release ZIP.
4. Double-click `install.cmd`.
5. Paste your Clear Sky installation folder when asked. For example:

   ```text
   F:\SteamLibrary\steamapps\common\STALKER Clear Sky
   ```

The installer patches six bytes in your own `bin\xrEngine.exe`, adds the F2 command to `_appdata_\user.ltx`, and creates a dated `_abr_noclip_backup_*` folder before changing anything.

PowerShell users can run the installer directly:

```powershell
.\install.ps1 -GamePath "F:\SteamLibrary\steamapps\common\STALKER Clear Sky"
```

## Controls

| Key | Action |
| --- | --- |
| F2 | Start native free flight |
| Mouse | Look around |
| Left / right mouse | Fly forward / backward |
| A / D | Strafe left / right |
| W / S | Rise / descend |
| Left Shift | Precision movement |
| Left Ctrl | Fast movement |
| Enter | Place the actor at the camera and exit |
| Escape | Cancel and return to the actor's original position |

While free flight is active, you are controlling the engine camera rather than the actor, so weapons and normal interactions are unavailable until you press Enter or Escape.

## Uninstallation

Close the game and double-click `uninstall.cmd`, then provide the Clear Sky installation folder. The uninstaller reverses the six-byte engine patch and removes the F2 console binding. Safety backups are intentionally kept.

You can also restore `xrEngine.exe` and `user.ltx` manually from the dated `_abr_noclip_backup_*` folder created during installation.

## Troubleshooting

- Use the main Enter key, not the numeric keypad Enter key.
- If Steam verifies or repairs the game files, run the installer again afterward.
- If F2 was previously assigned to another console command, the installer replaces that F2 console binding. The old configuration remains in the backup folder.
- Save before travelling outside the playable area. Placing the actor under the map, inside scripted doors, or in a level changer can break progression.
- If the installer reports an unsupported executable, do not force the patch. Open an issue and include the SHA-256 reported by this command:

  ```powershell
  Get-FileHash ".\bin\xrEngine.exe" -Algorithm SHA256
  ```

## Technical details

ABR's `xrEngine.exe` contains X-Ray's native Enter handler for `demo_record`, including the actor `ForceTransform` call, but a runtime conditional skips that path in normal play. The installer changes the conditional jump at file offset `0x41E1B` from `0F 84 C7 00 00 00` to six `NOP` bytes. All surrounding bytes and the complete executable hash are validated before and after patching.

No game executable, ABR asset, or GSC-owned file is distributed in this repository.

## Disclaimer

This is an unofficial community modification. It is not affiliated with or endorsed by GSC Game World, Steam, or the ABR CS MOD authors. S.T.A.L.K.E.R. and related names are the property of their respective owners.

## License

The installer scripts in this repository are available under the MIT License. The license does not apply to S.T.A.L.K.E.R., X-Ray Engine, Steam, or ABR CS MOD files.
