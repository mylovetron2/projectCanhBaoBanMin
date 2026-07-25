# Mine Alert Flutter

Flutter dashboard for monitoring a mine-alert sensor system. On Windows, the app can now talk to NI-DAQmx directly in-process without launching a separate bridge executable.

## Features

- Realtime simulated channels (`AI0..AI7`) with live line charts
- Built-in Windows NI-DAQmx bridge for direct hardware access
- Optional external bridge fallback for non-Windows targets
- Configurable warning/danger thresholds
- Acquisition controls (run/pause, sample interval)
- Event log when channels enter warning/danger state
- Responsive layout for desktop and smaller screens
- Pipeline supports local process bridge from any external adapter

## Data Acquisition Layer

The app now uses a dedicated acquisition service layer:

- `lib/data_acquisition_service.dart`: orchestrates data source mode (`mock` or `bridge`), run/pause, and sample emission
- `lib/daq_bridge_client.dart`: low-level bridge client that uses the in-process Windows bridge or an external adapter on other platforms
- `lib/main.dart`: UI-only state rendering and controls

This structure keeps hardware-specific integration outside the dashboard UI.

## Run (Windows)

1. Open terminal in this folder:
	- `d:\projectSumome\mine_alert_flutter`
2. Install dependencies:
	- `flutter pub get`
3. Run desktop app:
	- `flutter run -d windows`

## Bridge Mode (48 kHz MIC)

1. Start app in mock mode by default.
2. Enable switch in UI:
	- `Use built-in NI-DAQ bridge (multi-channel)` on Windows
	- `Use external DAQ bridge (multi-channel)` on other platforms
3. On Windows, NI-DAQmx is loaded directly inside the app. On other platforms, provide your own adapter executable path and arguments in the control panel.

Expected adapter output protocol (stdout, one line per frame):

- `DATA,<rate>,<samplesRead>,<rms>,<peak>`
- `ERROR,<message>`

Example adapter arguments (if your adapter supports them):
- `--stream --rate 48000 --samples 2400`

## Notes

- The folder `cdaq-9181-console` still contains the reference console implementation and can be used to compare protocol behavior.
- The Windows desktop app no longer needs to launch `cdaq9181_console.exe` as a separate process.
