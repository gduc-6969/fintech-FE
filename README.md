# Fintech Wallet frontend

## UI image archive

The 53 generated PNGs are retained in `test/ui_captures/`. The archive covers
authentication, Face ID, bank linking, wallet states, money movement,
transaction PIN/OTP verification, and transaction outcomes. Camera scanning,
PIN/OTP preview, and dashboard PNGs produced during the temporary capture pass
remain available without keeping preview-only hooks or capture fonts in the
production application. Native camera and permission behavior belongs in device
integration tests.

The wallet dashboard and bank flows use the test-only adapter in
`test/support/mock_wallet_api.dart`. Its loaded, empty, and error states never
replace the production API adapter outside tests.

## Device integration tests

Connect an Android device with USB debugging enabled, then run:

```powershell
flutter devices
.\tool\run_device_integration.ps1 -DeviceId <device-id>
```

The runner validates full wallet/bank navigation against the mock API, forces a
denied camera-permission state, grants the permission, and then verifies both
the QR scanner and front-camera Face ID preview using the real device plugins.
If the target has no front camera, the Face ID test validates the explicit
hardware-unavailable recovery state instead.
The default Android application ID is `com.fintech.fintech_fe`; pass
`-PackageName` if a flavor changes it.

The same test files can be launched manually on iOS, but camera permission must
be reset or granted through the simulator/device settings before selecting the
matching test name.
