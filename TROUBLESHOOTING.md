# Troubleshooting and verification

## Scanner beeps normally but nothing types

1. Click a text field in Notepad and scan a product UPC.
2. Confirm this computer received the computer setup, not just the scanner programming barcodes.
3. Check that the **CoreScanner** Windows service is Running and its startup type is Automatic.
4. Confirm the scanner uses SNAPI with Imaging. Keep 123Scan closed during ordinary keyboard-input testing.

The working path is: scanner -> USB SNAPI -> CoreScanner -> keyboard input in the focused application.

## Four low beeps and no text

Zebra's MP7000 Integrator Guide, Table 5-1 on printed page 5-22, identifies four low beeps as a barcode data transmission error.

On the tested unit, native USB HID Keyboard mode was visible as a healthy keyboard in Windows but repeatedly failed this physical input test. USB reconnect, scanner reboot, and temporary removal of the scanner suffix did not resolve native HID transmission. The workaround uses SNAPI instead.

Do not assume that healthy Device Manager enumeration proves barcode input works. Test physical scans in Notepad.

## A stray j appears after a scan

The original scan payload contained barcode digits followed by CR/LF. During CoreScanner emulation this sometimes produced an extra `j`.

Confirm both halves of the final setup:

- Scanner parameter **235 = 0**, **Data As Is**, so the scanner sends the digits without CR/LF.
- CoreScanner appends exactly one Enter: `SUFFIX2 = 13`, `DDFSELECT = 2`, and format 2 is `DATA.SUFFIX2`.

Do not add a second scanner suffix on top of the driver suffix.

## Digits appear but Enter is missing

Data As Is deliberately removes the scanner's suffix. The computer setup supplies Enter separately. Re-run the computer setup and check the generated result file for `Success: true`, `DdfSuffix2: "13"`, and `DdfSelection: "2"`.

## 123Scan reports a missing or invalid plug-in

The confirmed mismatch was between the exact `MP7001-LNS0M10US` / `PAADGC01-006-R00` combination and the installed/online catalog. A matching family name such as MP7001-COMMON did not establish compatibility.

Zebra's update service responded and returned the general catalog, but returned zero records for that exact model and firmware. This was separate from USB detection and keyboard-output configuration.

The keyboard-emulation method does not require a matching 123Scan plug-in. If full scanner management or firmware updates are needed, obtain the exact supported package from Zebra. This setup does not flash firmware.

## Configuration files and backups

- Active CoreScanner settings: `%ProgramFiles%\Zebra Technologies\Barcode Scanners\Common\Config.xml`.
- Computer setup backups/results: `Backups/<COMPUTERNAME>/` beside the setup script.
- 123Scan logs, when further troubleshooting is needed: `%PUBLIC%\Documents\123Scan2\Logs`.
- CoreScanner logs: `%ProgramFiles%\Zebra Technologies\Barcode Scanners\Common\Logs`.

Keep backups locally; the repository ignores the generated backup directory.

## Deployment checklist

For the first additional unit, record the exact model and firmware, apply the two scanner barcodes on a prepared computer, and scan several UPCs. Check one number plus one Enter per scan, with no extra letters or blank lines. Reconnect or power-cycle the scanner and repeat the scan test.

On each destination PC, verify the CoreScanner service starts automatically. A full Windows reboot should be part of your deployment acceptance check; that test was not performed during the original troubleshooting session.

## Rollback

Run `Undo-Computer-Setup.cmd` as administrator to disable emulation and restore the original saved driver-formatting values. The computer-side undo does not restore scanner settings.

For the originally tested unit, the scanner's pre-change USB mode was IBM Hand-held (`XUA-45001-1`) and its original scan data format was parameter 235 = 1. Other units may start with different settings; record their own initial configuration before changing them.

## Sources

- [Zebra Scanner SDK for Windows](https://techdocs.zebra.com/dcs/scanners/sdk-windows/).
- [MP7000 Integrator Guide](https://www.zebra.com/content/dam/support-dam/en/documentation/unrestricted/guide/product/mp7x00-ig-en.pdf).
- [MP7000 Barcode Programming Guide](https://www.zebra.com/content/dam/support-dam/en/documentation/unrestricted/guide/product/mp7x00-prg-en.pdf).
