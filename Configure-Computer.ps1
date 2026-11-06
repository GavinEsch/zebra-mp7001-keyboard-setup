# Run once per destination PC as administrator. Compatible with Windows PowerShell 5.1 and PowerShell 7.
# Add -Disable to restore the saved computer settings.
# Enables emulation and appends exactly one CR/Enter through driver formatting.
# Scanner USB mode is configured separately through the documented Zebra SDK.
param([switch]$Disable)
$ErrorActionPreference = 'Stop'
$backupDirectory = Join-Path (Join-Path $PSScriptRoot 'Backups') $env:COMPUTERNAME
New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
$resultPath = Join-Path $backupDirectory 'Computer-setup-result.json'
$configPath = 'C:\Program Files\Zebra Technologies\Barcode Scanners\Common\Config.xml'
$backupPath = Join-Path $backupDirectory 'CoreScanner-Config-before.xml'
$serviceBackupPath = Join-Path $backupDirectory 'CoreScanner-service-before.json'
$result = [ordered]@{
    Timestamp = (Get-Date).ToString('o')
    Success = $false
    ConfigPath = $configPath
    Setting = '/CONFIG/SIMULATED_HID_KB_SETTINGS/ENABLE'
    RequestedValue = $(if ($Disable) { '0' } else { '1' })
    ConfigSaved = $false
    ServiceRestarted = $false
}
try {
    $principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Right-click Run-Computer-Setup.cmd and select Run as administrator.'
    }
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { throw 'CoreScanner Config.xml was not found.' }
    if (-not (Test-Path -LiteralPath $backupPath)) { Copy-Item -LiteralPath $configPath -Destination $backupPath }
    $document = [xml]::new()
    $document.PreserveWhitespace = $true
    $document.Load($configPath)
    $formatDefinition = $document.SelectSingleNode("/CONFIG/DDF/DDFMETA/DDFDEF[@DdfCode='2']")
    if ($null -eq $formatDefinition -or $formatDefinition.GetAttribute('DdfFormat') -ne 'DATA.SUFFIX2') {
        throw 'Expected DATA.SUFFIX2 driver format was not found; no change made.'
    }
    $node = $document.SelectSingleNode('/CONFIG/SIMULATED_HID_KB_SETTINGS/ENABLE')
    if ($null -eq $node) { throw 'Expected keyboard emulation setting was not found; no change made.' }
    $result.PreviousValue = $node.InnerText
    $raw = [IO.File]::ReadAllText($configPath)
    $pattern = '(?s)(<SIMULATED_HID_KB_SETTINGS>.*?<ENABLE>)\s*[01]\s*(</ENABLE>.*?</SIMULATED_HID_KB_SETTINGS>)'
    $matches = [regex]::Matches($raw, $pattern)
    if ($matches.Count -ne 1) { throw 'Expected exactly one keyboard emulation block; no change made.' }
    $match = $matches[0]
    $replacement = $match.Groups[1].Value + $result.RequestedValue + $match.Groups[2].Value
    $updated = $raw.Substring(0, $match.Index) + $replacement + $raw.Substring($match.Index + $match.Length)
    $baseline = [xml]::new()
    $baseline.Load($backupPath)
    $formatChanges = @(
        @{
            XPath = '/CONFIG/SIMULATED_HID_KB_SETTINGS/FUNCTION_KEY_MAPPING'
            Pattern = '(<FUNCTION_KEY_MAPPING>)[^<]*(</FUNCTION_KEY_MAPPING>)'
            Value = $(if ($Disable) { $baseline.SelectSingleNode('/CONFIG/SIMULATED_HID_KB_SETTINGS/FUNCTION_KEY_MAPPING').InnerText } else { '1' })
        },
        @{
            XPath = '/CONFIG/DDF/DDFMETA/SUFFIX2'
            Pattern = '(<SUFFIX2>)[^<]*(</SUFFIX2>)'
            Value = $(if ($Disable) { $baseline.SelectSingleNode('/CONFIG/DDF/DDFMETA/SUFFIX2').InnerText } else { '13' })
        },
        @{
            XPath = '/CONFIG/DDF/DDFSELECT'
            Pattern = '(<DDFSELECT>)[^<]*(</DDFSELECT>)'
            Value = $(if ($Disable) { $baseline.SelectSingleNode('/CONFIG/DDF/DDFSELECT').InnerText } else { '2' })
        }
    )
    foreach ($change in $formatChanges) {
        if ($null -eq $document.SelectSingleNode($change.XPath)) { throw "Missing setting $($change.XPath); no change made." }
        $formatMatches = [regex]::Matches($updated, $change.Pattern)
        if ($formatMatches.Count -ne 1) { throw "Ambiguous setting $($change.XPath); no change made." }
        $formatMatch = $formatMatches[0]
        $updated = $updated.Substring(0, $formatMatch.Index) + $formatMatch.Groups[1].Value + $change.Value +
            $formatMatch.Groups[2].Value + $updated.Substring($formatMatch.Index + $formatMatch.Length)
    }
    [xml]$validation = $updated
    if ($validation.SelectSingleNode('/CONFIG/SIMULATED_HID_KB_SETTINGS/ENABLE').InnerText -ne $result.RequestedValue) {
        throw 'Proposed configuration failed validation; no change made.'
    }
    foreach ($change in $formatChanges) {
        if ($validation.SelectSingleNode($change.XPath).InnerText -ne $change.Value) { throw 'Driver formatting validation failed; no change made.' }
    }
    $result.DdfSuffix2 = $validation.SelectSingleNode('/CONFIG/DDF/DDFMETA/SUFFIX2').InnerText
    $result.DdfSelection = $validation.SelectSingleNode('/CONFIG/DDF/DDFSELECT').InnerText
    $temporaryPath = $configPath + '.codex-' + [guid]::NewGuid().ToString('N') + '.tmp'
    $bytes = [IO.File]::ReadAllBytes($configPath)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191
    [IO.File]::WriteAllText($temporaryPath, $updated, [Text.UTF8Encoding]::new($hasBom))
    [IO.File]::Replace($temporaryPath, $configPath, [System.Management.Automation.Language.NullString]::Value)
    $result.ConfigSaved = $true
    if (-not (Test-Path -LiteralPath $serviceBackupPath)) {
        @{StartType=(Get-Service -Name 'CoreScanner').StartType.ToString()} | ConvertTo-Json | Set-Content -LiteralPath $serviceBackupPath
    }
    if ($Disable) {
        $serviceBaseline = Get-Content -LiteralPath $serviceBackupPath -Raw | ConvertFrom-Json
        if ($serviceBaseline.StartType -notin @('Automatic', 'Manual', 'Disabled')) { throw 'Invalid service startup backup.' }
        if ($serviceBaseline.StartType -ne 'Disabled') { Set-Service -Name 'CoreScanner' -StartupType $serviceBaseline.StartType }
    } else {
        Set-Service -Name 'CoreScanner' -StartupType Automatic
    }
    Restart-Service -Name 'CoreScanner' -ErrorAction Stop
    $service = Get-Service -Name 'CoreScanner'
    $service.WaitForStatus([ServiceProcess.ServiceControllerStatus]::Running, [TimeSpan]::FromSeconds(20))
    $result.ServiceRestarted = $true
    $verified = [xml]::new()
    $verified.Load($configPath)
    if ($verified.SelectSingleNode('/CONFIG/SIMULATED_HID_KB_SETTINGS/ENABLE').InnerText -ne $result.RequestedValue) {
        throw 'Configuration read-back did not match the requested value.'
    }
    $result.ServiceStatus = (Get-Service -Name 'CoreScanner').Status.ToString()
    $result.Success = $true
} catch {
    $result.Error = $_.Exception.Message
} finally {
    $result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $resultPath -Encoding utf8
}
$result | ConvertTo-Json -Depth 4
if (-not $result.Success) { exit 1 }
Write-Host 'Computer configured. Close 123Scan, program each scanner with the two supplied barcodes, and test UPC + Enter.'
