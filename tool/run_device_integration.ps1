param(
  [Parameter(Mandatory = $true)]
  [string]$DeviceId,
  [string]$PackageName = 'com.fintech.fintech_fe',
  [string]$AdbPath
)

$ErrorActionPreference = 'Stop'
$cameraPermission = 'android.permission.CAMERA'

function Resolve-AdbExecutable {
  if ($AdbPath) {
    if (-not (Test-Path -LiteralPath $AdbPath -PathType Leaf)) {
      throw "ADB was not found at '$AdbPath'."
    }
    return (Resolve-Path -LiteralPath $AdbPath).Path
  }

  $adbCommand = Get-Command adb -ErrorAction SilentlyContinue
  if ($adbCommand) {
    return $adbCommand.Source
  }

  $sdkCandidates = @($env:ANDROID_SDK_ROOT, $env:ANDROID_HOME) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
  $flutterAndroidSetting = flutter config --list |
    Select-String -Pattern '^\s*android-sdk:\s*(.+)$' |
    Select-Object -First 1
  if ($flutterAndroidSetting) {
    $sdkCandidates += $flutterAndroidSetting.Matches[0].Groups[1].Value.Trim()
  }

  foreach ($sdkRoot in $sdkCandidates) {
    foreach ($adbName in @('adb.exe', 'adb')) {
      $candidate = Join-Path $sdkRoot "platform-tools\$adbName"
      if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        return (Resolve-Path -LiteralPath $candidate).Path
      }
    }
  }

  throw 'Unable to locate adb. Pass -AdbPath or configure Flutter android-sdk.'
}

$adbExecutable = Resolve-AdbExecutable

function Invoke-Checked {
  param(
    [Parameter(Mandatory = $true)]
    [scriptblock]$Command,
    [Parameter(Mandatory = $true)]
    [string]$Description
  )

  & $Command
  if ($LASTEXITCODE -ne 0) {
    throw "$Description failed with exit code $LASTEXITCODE."
  }
}

Invoke-Checked -Description 'Wallet navigation integration test' -Command {
  flutter test integration_test/wallet_navigation_test.dart -d $DeviceId --no-uninstall
}

& $adbExecutable -s $DeviceId shell pm revoke $PackageName $cameraPermission 2>$null
& $adbExecutable -s $DeviceId shell pm set-permission-flags $PackageName $cameraPermission user-set user-fixed
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to place CAMERA in the denied state. Check the package name and Android API level.'
}

Invoke-Checked -Description 'Denied camera permission integration test' -Command {
  flutter test integration_test/device_capabilities_test.dart -d $DeviceId --no-uninstall --plain-name 'camera permission denied shows QR recovery state'
}

Invoke-Checked -Description 'Clear camera permission flags' -Command {
  & $adbExecutable -s $DeviceId shell pm clear-permission-flags $PackageName $cameraPermission user-set user-fixed
}
Invoke-Checked -Description 'Grant camera permission' -Command {
  & $adbExecutable -s $DeviceId shell pm grant $PackageName $cameraPermission
}

Invoke-Checked -Description 'QR camera integration test' -Command {
  flutter test integration_test/device_capabilities_test.dart -d $DeviceId --no-uninstall --plain-name 'granted camera initializes QR scanner'
}

Invoke-Checked -Description 'Grant camera permission for front-camera test' -Command {
  & $adbExecutable -s $DeviceId shell pm grant $PackageName $cameraPermission
}
Invoke-Checked -Description 'Front camera integration test' -Command {
  flutter test integration_test/device_capabilities_test.dart -d $DeviceId --no-uninstall --plain-name 'front camera initializes or reports hardware unavailable'
}

Write-Host 'Device integration tests passed.' -ForegroundColor Green
