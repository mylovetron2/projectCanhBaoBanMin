# Mine Alert Flutter

Flutter dashboard for monitoring a mine-alert sensor system. The current build uses mock realtime data and is structured to later connect to a real NI-DAQmx data bridge.

## Features

- Realtime simulated channels (`AI0..AI7`) with live line charts
- Optional external NI-DAQmx bridge source at `48 kHz` (MIC)
- Configurable warning/danger thresholds
- Acquisition controls (run/pause, sample interval)
- Event log when channels enter warning/danger state
- Responsive layout for desktop and smaller screens
- Pipeline supports local process bridge from any external adapter

## Data Acquisition Layer

The app now uses a dedicated acquisition service layer:

- `lib/data_acquisition_service.dart`: orchestrates data source mode (`mock` or `bridge`), run/pause, and sample emission
- `lib/daq_bridge_client.dart`: low-level process runner + stdout parser for external adapter
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
	- `Use external DAQ bridge (MIC 48 kHz)`
3. Provide your own adapter executable path and arguments in the control panel.

Expected adapter output protocol (stdout, one line per frame):

- `DATA,<rate>,<samplesRead>,<rms>,<peak>`
- `ERROR,<message>`

Example adapter arguments (if your adapter supports them):
- `--stream --rate 48000 --samples 2400`

## Next Integration Step

The folder `cdaq-9181-console` in this workspace is reference material only. The Flutter app is not hard-coupled to it.
