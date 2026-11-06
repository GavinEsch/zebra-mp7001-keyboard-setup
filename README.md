# Zebra MP7001 keyboard setup for Windows

Make a Zebra MP7001 type UPC digits followed by **one Enter** into the focused Windows application, using USB SNAPI and Zebra CoreScanner's software keyboard emulation.

This reproduces the working configuration tested on **MP7001-LNS0M10US**, firmware **PAADGC01-006-R00** (combined firmware **CAADGC01-006-R00**), with **123Scan 6.01.0005** and **CoreScanner 3.08.0022**.

**Every destination computer needs the computer setup.** This is software keyboard emulation on Windows. The scanner does not become a standalone HID keyboard that can be moved to any unprepared computer.

## Quick setup

Download [MP7001-Repeat-Setup.zip](MP7001-Repeat-Setup.zip) and extract it to a local folder. The archive contains the scripts, instructions, and printable scanner barcodes.

### Once per Windows computer

1. Install [Zebra 123Scan](https://www.zebra.com/us/en/support-downloads/software/scanner-software/123scan-utility.html), including its CoreScanner component.
2. Close 123Scan.
3. Right-click **Run-Computer-Setup.cmd** and choose **Run as administrator**.
4. Approve the Windows administrator prompt and check that the result shows `Success: true`.

The script targets 64-bit Windows with the default Zebra installation path. It saves a backup under `Backups/<COMPUTERNAME>/`, enables keyboard emulation, adds one Enter through driver formatting, and sets CoreScanner to start automatically.

### Once per scanner

1. Connect the scanner's **POS USB** port to a prepared computer and supply normal scanner power. Configure one scanner at a time, with 123Scan closed.
2. Print [Scanner-Programming-Barcodes.pdf](Scanner-Programming-Barcodes.pdf) at **Actual size / 100%**.
3. Scan page 1: **Symbol Native API (SNAPI) with Imaging Interface**. Wait for startup/reconnection beeps and Windows device detection.
4. Scan page 2: **Data As Is**.
5. Click inside Notepad and scan several UPCs. Expect one complete number per line, with no extra letters or blank lines.
6. Reconnect or power-cycle the scanner and repeat the test before deployment.

The original scanner was configured through Zebra's CoreScanner SDK. The supplied barcode pages are Zebra's documented equivalents of those settings. Validate this barcode procedure on the next unit before configuring the whole batch, especially if model or firmware differs.

## Saved configuration

| Location | Setting | Value |
| --- | --- | --- |
| Scanner | USB host mode | SNAPI with Imaging, permanent; SDK host code `XUA-45001-9` |
| Scanner | Scan Data Transmission Format, parameter 235 | `0` - Data As Is |
| Computer | `SIMULATED_HID_KB_SETTINGS/ENABLE` | `1` |
| Computer | `SIMULATED_HID_KB_SETTINGS/FUNCTION_KEY_MAPPING` | `1` |
| Computer | `DDF/DDFMETA/SUFFIX2` | `13` - one CR/Enter |
| Computer | `DDF/DDFSELECT` | `2` - existing `DATA.SUFFIX2` format |
| Computer | CoreScanner service startup | Automatic |

CoreScanner reads `C:\Program Files\Zebra Technologies\Barcode Scanners\Common\Config.xml`. The setup script updates the relevant settings, preserves the other configuration content, and restarts CoreScanner to load the change.

For normal use, sign in to Windows, focus the application input field, and scan. **123Scan can remain closed; CoreScanner must remain installed and running.**

## Why this method was used

123Scan detected the scanner but could not find a plug-in matching the exact model and `C01` firmware branch. The installed COMMON SR/DL revision 043 plug-ins described the `PAADGS00-006-R05` branch and omitted the exact tested model. The online catalog also returned no exact match, despite working DNS and HTTPS connectivity.

Native HID keyboard mode enumerated as a healthy Windows keyboard but produced four low beeps and no barcode input on the tested unit. Its underlying transmission failure remains unresolved. SNAPI successfully delivered barcode data, so the working setup uses Zebra's documented CoreScanner keyboard emulation.

The original scanner suffix contained CR/LF. During software emulation, it sometimes produced an extra `j`. Sending digits only from the scanner and adding a single Enter in CoreScanner removed the extra character.

No firmware update, factory reset, scale calibration change, or driver replacement was needed.

## Validation and limits

- Physical scans produced clean UPC lines in Notepad, with one Enter and no stray `j`.
- Saved SNAPI mode and parameter 235 were read back after scanner reboots.
- Keyboard emulation remained enabled after a CoreScanner service restart.
- The printable PDF was rendered and visually checked. Windows PowerShell 5.1 and PowerShell 7 syntax, plus the atomic file replacement used by the script, were checked.
- A full Windows reboot and additional scanner units have not yet been tested.
- The computer script configures CoreScanner only. The two scanner settings are applied separately with the programming barcodes.

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for symptoms, verification, and rollback details.

## Undo

Right-click **Undo-Computer-Setup.cmd** and choose **Run as administrator** to disable software keyboard emulation and restore the saved driver-formatting values. Keep the setup folder and its `Backups` directory.

This does not restore the scanner's USB mode or parameter 235. Their original values must be restored separately if needed.

## Official references

- [Zebra Scanner SDK for Windows](https://techdocs.zebra.com/dcs/scanners/sdk-windows/): SNAPI, simulated HID keyboard output, persistent configuration, and driver data formatting.
- [123Scan support and download](https://www.zebra.com/us/en/support-downloads/software/scanner-software/123scan-utility.html).
- [MP7000 Barcode Programming Guide](https://www.zebra.com/content/dam/support-dam/en/documentation/unrestricted/guide/product/mp7x00-prg-en.pdf): printed pages 2-9 and 6-95.

The included PDF contains two selected Zebra documentation pages. See [NOTICE.md](NOTICE.md) for attribution. Device serial numbers, local configuration backups, and raw diagnostic logs are not included in this repository.
