import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'daq_bridge_client.dart';
import 'data_acquisition_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const ColorScheme appColors = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF0B4F8A),
      onPrimary: Colors.white,
      secondary: Color(0xFF1F7A8C),
      onSecondary: Colors.white,
      error: Color(0xFFB3261E),
      onError: Colors.white,
      surface: Color(0xFFF7FAFC),
      onSurface: Color(0xFF1E2936),
      primaryContainer: Color(0xFFD9EAF7),
      onPrimaryContainer: Color(0xFF082E52),
      secondaryContainer: Color(0xFFD9EEF2),
      onSecondaryContainer: Color(0xFF123D47),
      errorContainer: Color(0xFFF9DEDC),
      onErrorContainer: Color(0xFF410E0B),
      surfaceContainerHighest: Color(0xFFE8EEF4),
      onSurfaceVariant: Color(0xFF4A5A6A),
      outline: Color(0xFFC8D4E0),
      outlineVariant: Color(0xFFD9E2EC),
      shadow: Color(0x33000000),
      scrim: Color(0x66000000),
      inverseSurface: Color(0xFF243447),
      onInverseSurface: Color(0xFFF2F6FA),
      inversePrimary: Color(0xFF8CBEE8),
      surfaceTint: Color(0xFF0B4F8A),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cảnh báo bắn mìn - Địa vật lý Giếng Khoang',
      theme: ThemeData(
        colorScheme: appColors,
        scaffoldBackgroundColor: const Color(0xFFF2F6FB),
        canvasColor: const Color(0xFFF2F6FB),
        dividerColor: const Color(0xFFD7E0EA),
        visualDensity: VisualDensity.standard,
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E2936),
          ),
          titleMedium: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E2936),
          ),
          bodyMedium: TextStyle(color: Color(0xFF2E3C4A), height: 1.35),
          bodySmall: TextStyle(color: Color(0xFF5A6878), height: 1.3),
          labelLarge: TextStyle(fontWeight: FontWeight.w600),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFEAF3FB),
          foregroundColor: Color(0xFF1A2530),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A2530),
            fontFamilyFallback: <String>[
              'Segoe UI',
              'Arial',
              'Noto Sans',
              'sans-serif',
            ],
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFDCE5EF)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0B4F8A),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0B4F8A),
            side: const BorderSide(color: Color(0xFFB6CCE2)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF7FAFD),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFD2DCE7)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFD2DCE7)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF0B4F8A), width: 1.4),
          ),
          labelStyle: const TextStyle(color: Color(0xFF4E5E6E)),
          hintStyle: const TextStyle(color: Color(0xFF8A98A8)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 58,
          backgroundColor: const Color(0xFFFFFFFF),
          indicatorColor: const Color(0xFFD9EAF7),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
            final bool selected = states.contains(WidgetState.selected);
            return IconThemeData(
              size: selected ? 22 : 20,
              color: selected
                  ? const Color(0xFF0B4F8A)
                  : const Color(0xFF667788),
            );
          }),
          labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0B4F8A),
              );
            }
            return const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF667788),
            );
          }),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFF1F6FB),
          selectedColor: const Color(0xFFD9EAF7),
          side: const BorderSide(color: Color(0xFFCAD8E6)),
          labelStyle: const TextStyle(color: Color(0xFF324456)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF203449),
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        useMaterial3: true,
      ),
      home: const MineAlertDashboard(),
    );
  }
}

enum SensorState { normal, warning, danger }

enum _EventLogLevel { info, warning, danger }

enum _EventLogFilter { all, info, warning, danger }

class _CombinedWindowOption {
  const _CombinedWindowOption({required this.label, required this.minutes});

  final String label;
  final int minutes;
}

enum BridgeAiChannelMode { voltage, accel }

class _AccelSensorPreset {
  const _AccelSensorPreset({
    required this.id,
    required this.label,
    required this.sensitivityMvPerG,
    this.isCustom = false,
  });

  final String id;
  final String label;
  final double sensitivityMvPerG;
  final bool isCustom;
}

class _LoggedSample {
  const _LoggedSample({
    required this.timestamp,
    required this.values,
    this.sampleRateHz,
    this.samplesRead,
    this.wavePayloadJson,
    this.fftPayloadJson,
    this.wavePayloadBytes,
    this.fftPayloadBytes,
  });

  final DateTime timestamp;
  final Map<String, double> values;
  final int? sampleRateHz;
  final int? samplesRead;
  final String? wavePayloadJson;
  final String? fftPayloadJson;
  final Uint8List? wavePayloadBytes;
  final Uint8List? fftPayloadBytes;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'timestamp': timestamp.toIso8601String(),
      'sampleRateHz': sampleRateHz,
      'samplesRead': samplesRead,
      'values': values,
      'wavePayloadJson': wavePayloadJson,
      'fftPayloadJson': fftPayloadJson,
    };
  }

  static _LoggedSample? fromJsonString(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final Object? valuesRaw = decoded['values'];
      if (valuesRaw is! Map) {
        return null;
      }

      final DateTime? timestamp = DateTime.tryParse(
        decoded['timestamp']?.toString() ?? '',
      );
      if (timestamp == null) {
        return null;
      }

      final Map<String, double> values = <String, double>{};
      for (final MapEntry<dynamic, dynamic> entry in valuesRaw.entries) {
        final String key = entry.key.toString();
        final Object? value = entry.value;
        if (value is num) {
          values[key] = value.toDouble();
        }
      }

      return _LoggedSample(
        timestamp: timestamp,
        values: values,
        sampleRateHz: (decoded['sampleRateHz'] as num?)?.toInt(),
        samplesRead: (decoded['samplesRead'] as num?)?.toInt(),
        wavePayloadJson: decoded['wavePayloadJson']?.toString(),
        fftPayloadJson: decoded['fftPayloadJson']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  String? strongestChannel() {
    String? strongest;
    double maxValue = double.negativeInfinity;
    for (final MapEntry<String, double> entry in values.entries) {
      if (entry.value > maxValue) {
        maxValue = entry.value;
        strongest = entry.key;
      }
    }
    return strongest;
  }

  double strongestValue() {
    double maxValue = 0;
    for (final double value in values.values) {
      if (value > maxValue) {
        maxValue = value;
      }
    }
    return maxValue;
  }
}

class _BinaryTimeIndexEntry {
  const _BinaryTimeIndexEntry({
    required this.timestampMsUtc,
    required this.byteOffset,
    required this.sampleIndex,
  });

  final int timestampMsUtc;
  final int byteOffset;
  final int sampleIndex;
}

class _BinaryReplayLoadResult {
  const _BinaryReplayLoadResult({
    required this.samples,
    required this.timeIndex,
    required this.indexStride,
  });

  final List<_LoggedSample> samples;
  final List<_BinaryTimeIndexEntry> timeIndex;
  final int indexStride;
}

class MineAlertDashboard extends StatefulWidget {
  const MineAlertDashboard({super.key});

  @override
  State<MineAlertDashboard> createState() => _MineAlertDashboardState();
}

class _MineAlertDashboardState extends State<MineAlertDashboard>
    with WidgetsBindingObserver {
  static const String _prefBridgePath = 'settings.bridgePath';
  static const String _prefBridgeArgs = 'settings.bridgeArgs';
  static const String _prefVoltageMin = 'settings.voltageMin';
  static const String _prefVoltageMax = 'settings.voltageMax';
  static const String _prefUseBridge = 'settings.useBridge';
  static const String _prefChartMinG = 'settings.chartMinG';
  static const String _prefChartMaxG = 'settings.chartMaxG';
  static const String _prefWaveformTimeWindowMs =
      'settings.waveformTimeWindowMs';
  static const String _prefWaveformTimeWindowMinMs =
      'settings.waveformTimeWindowMinMs';
  static const String _prefWaveformTimeWindowMaxMs =
      'settings.waveformTimeWindowMaxMs';
  static const String _prefAiChannelMode = 'settings.aiChannelMode';
  static const String _prefAccelPresetId = 'settings.accelPresetId';
  static const String _prefAccelSensitivityMvPerG =
      'settings.accelSensitivityMvPerG';
  static const String _prefSampleRateHz = 'settings.sampleRateHz';
  static const String _prefSamplesPerRead = 'settings.samplesPerRead';
  static const String _prefLastAutoFallbackAt =
      'settings.lastAutoFallbackAtIso';
  static const String _prefLastAutoFallbackReason =
      'settings.lastAutoFallbackReason';
  static const String _prefDataLoggingEnabled = 'settings.dataLoggingEnabled';
  static const String _prefRecentLoggedSamples = 'settings.recentLoggedSamples';

  final List<String> _channels = List.generate(16, (index) => 'AI$index');
  final Map<String, List<FlSpot>> _history = <String, List<FlSpot>>{};
  final Map<String, double> _latestValues = <String, double>{};
  final Map<String, double> _latestRawRmsVolts = <String, double>{};
  final Map<String, SensorState> _lastStates = <String, SensorState>{};
  final List<String> _eventLogs = <String>[];
  final List<_LoggedSample> _dataLogs = <_LoggedSample>[];
  final Map<String, List<FlSpot>> _replayHistory = <String, List<FlSpot>>{};
  List<_LoggedSample> _replaySamples = <_LoggedSample>[];

  late final DataAcquisitionService _acquisitionService;
  StreamSubscription<AcquisitionSample>? _sampleSub;
  StreamSubscription<String>? _statusSub;

  bool _isRunning = true;
  bool _isConnected = false;
  bool _useBridge = true;
  bool _dataLoggingEnabled = true;
  bool _dataLoggingBlinkOn = true;
  DateTime? _dataLoggingSessionStartAt;
  File? _dataLoggingSessionFile;
  RandomAccessFile? _dataLoggingSessionSink;
  final List<_BinaryTimeIndexEntry> _dataLogTimeIndex =
      <_BinaryTimeIndexEntry>[];
  int _dataLogRecordCount = 0;
  bool _isReplayMode = false;
  bool _isReplayPlaying = false;
  bool _isLoadingReplayFile = false;
  double _replayLoadProgress = 0;
  bool _autoRecoveringAccelUnsupported = false;
  DateTime? _lastAutoFallbackAt;
  String _lastAutoFallbackReason = '';
  int _selectedScreenIndex = 0;
  int _selectedCombinedWindowMinutes = -1;
  _EventLogFilter _selectedEventLogFilter = _EventLogFilter.all;
  String _fftChannel = 'AI0';

  // Latest FFT from C bridge (bridge mode only; empty in mock mode)
  final Map<String, List<double>> _bridgeFftMags = <String, List<double>>{};
  int _bridgeFftSampleRateHz = 0;
  int _bridgeFftBinCount = 0;
  int _bridgeFftSamplesRead = 0;
  DateTime? _bridgeFftCapturedAt;

  // Latest raw waveform from C bridge (bridge mode only)
  final Map<String, List<double>> _bridgeWaveSamples = <String, List<double>>{};
  int _bridgeWaveSampleRateHz = 0;
  int _bridgeWaveDecimStep = 1;
  DateTime? _bridgeWaveCapturedAt;
  String _waveChannel = 'AI0';
  double _waveformTimeWindowMs = 200.0; // User-configurable time axis scale
  double _waveformTimeWindowMinMs = 20.0;
  double _waveformTimeWindowMaxMs = 2000.0;
  final Set<String> _hiddenChannels = <String>{};
  final Set<String> _hiddenCombinedChannels = <String>{};
  double _warningThreshold = 0.65;
  double _dangerThreshold = 0.85;
  int _sampleIntervalMs = 500;
  double _voltageMin = -10.0;
  double _voltageMax = 10.0;
  double _chartMinG = 0.0;
  double _chartMaxG = 1.2;
  double _fftMaxY = 0.01;
  int _sampleRateHz = 10000;
  int _samplesPerRead = 1000;
  int? _actualSampleRateHz;
  int? _actualSamplesPerRead;
  BridgeAiChannelMode _aiChannelMode = BridgeAiChannelMode.voltage;
  String _selectedAccelPresetId = 'EX607A01';
  double _customAccelSensitivityMvPerG = 100.0;

  String _bridgeExecutablePath =
      'd:\\projectSumome\\cdaq-9181-console\\build\\cdaq9181_console.exe';
  String _bridgeArguments =
      '--stream --rate 10000 --samples 1000 --min -10 --max 10 --ai-mode voltage cDAQ9181-1E439C1Mod1/ai0:15';
  late final TextEditingController _bridgePathController;
  late final TextEditingController _bridgeArgsController;
  late final TextEditingController _voltageMinController;
  late final TextEditingController _voltageMaxController;
  late final TextEditingController _sampleRateController;
  late final TextEditingController _samplesPerReadController;
  late final TextEditingController _chartMinController;
  late final TextEditingController _chartMaxController;
  late final TextEditingController _accelSensitivityController;
  late final TextEditingController _waveformTimeWindowController;
  late final TextEditingController _waveformTimeWindowMinController;
  late final TextEditingController _waveformTimeWindowMaxController;
  Timer? _dataLogSaveDebounce;
  Timer? _dataLoggingBlinkTimer;
  Directory? _dataLogDirectory;
  Timer? _replayTimer;
  int _replayFrameIndex = -1;
  double _replayPositionMs = 0;
  double _replayPositionAtPlayStartMs = 0;
  double _replaySpeed = 1.0;
  DateTime? _replayPlayStartedAt;
  String? _replayFilePath;
  List<_BinaryTimeIndexEntry> _replayTimeIndex = <_BinaryTimeIndexEntry>[];
  int _replayIndexStride = 1;

  static const Duration _historyRetention = Duration(hours: 4);
  static const int _maxRecentDataLogs = 200;
  static const String _binaryLogExtension = 'smm';
  static const String _binaryLogMagic = 'MALOGB03';
  static const String _binaryIndexMagic = 'MALIDX01';
  static const int _binaryLogHeaderSize = 32;
  static const int _binaryIndexHeaderSize = 16;
  static const int _binaryIndexEntrySize = 16;
  static const int _binaryIndexStride = 16;
  static const Duration _binaryLogRotateEvery = Duration(days: 2);
  static const int _combinedRealtimeSeconds = 60;
  static const List<double> _replaySpeedOptions = <double>[0.5, 1, 2, 4, 8];
  static const List<_AccelSensorPreset> _accelPresets = <_AccelSensorPreset>[
    _AccelSensorPreset(
      id: 'EX607A01',
      label: 'EX607A01 (100 mV/g)',
      sensitivityMvPerG: 100.0,
    ),
    _AccelSensorPreset(
      id: 'ICP_500',
      label: 'ICP Generic (500 mV/g)',
      sensitivityMvPerG: 500.0,
    ),
    _AccelSensorPreset(
      id: 'CUSTOM',
      label: 'Custom',
      sensitivityMvPerG: 100.0,
      isCustom: true,
    ),
  ];
  static const List<_CombinedWindowOption> _combinedWindowOptions =
      <_CombinedWindowOption>[
        _CombinedWindowOption(label: 'Thời gian thực', minutes: -1),
        _CombinedWindowOption(label: '15p', minutes: 15),
        _CombinedWindowOption(label: '30p', minutes: 30),
        _CombinedWindowOption(label: '1h', minutes: 60),
        _CombinedWindowOption(label: '2h', minutes: 120),
        _CombinedWindowOption(label: '4h', minutes: 240),
        _CombinedWindowOption(label: 'Tất cả', minutes: 0),
      ];
  static const List<Color> _channelPalette = <Color>[
    Color(0xFF1F77B4),
    Color(0xFFFF7F0E),
    Color(0xFF2CA02C),
    Color(0xFFD62728),
    Color(0xFF9467BD),
    Color(0xFF8C564B),
    Color(0xFFE377C2),
    Color(0xFF7F7F7F),
    Color(0xFFBCBD22),
    Color(0xFF17BECF),
    Color(0xFF4E79A7),
    Color(0xFFF28E2B),
    Color(0xFFE15759),
    Color(0xFF76B7B2),
    Color(0xFF59A14F),
    Color(0xFFEDC948),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bridgePathController = TextEditingController(text: _bridgeExecutablePath);
    _bridgeArgsController = TextEditingController(text: _bridgeArguments);
    _voltageMinController = TextEditingController(text: _voltageMin.toString());
    _voltageMaxController = TextEditingController(text: _voltageMax.toString());
    _sampleRateController = TextEditingController(
      text: _sampleRateHz.toString(),
    );
    _samplesPerReadController = TextEditingController(
      text: _samplesPerRead.toString(),
    );
    _chartMinController = TextEditingController(text: _chartMinG.toString());
    _chartMaxController = TextEditingController(text: _chartMaxG.toString());
    _accelSensitivityController = TextEditingController(
      text: _customAccelSensitivityMvPerG.toString(),
    );
    _waveformTimeWindowController = TextEditingController(
      text: _waveformTimeWindowMs.toString(),
    );
    _waveformTimeWindowMinController = TextEditingController(
      text: _waveformTimeWindowMinMs.toString(),
    );
    _waveformTimeWindowMaxController = TextEditingController(
      text: _waveformTimeWindowMaxMs.toString(),
    );
    _acquisitionService = DataAcquisitionService(channels: _channels);
    _syncAcquisitionSignalUnit();

    for (final String channel in _channels) {
      _history[channel] = <FlSpot>[];
      _replayHistory[channel] = <FlSpot>[];
      _latestValues[channel] = 0;
      _latestRawRmsVolts[channel] = 0;
      _lastStates[channel] = SensorState.normal;
    }

    _sampleSub = _acquisitionService.samples.listen(_onAcquisitionSample);
    _statusSub = _acquisitionService.status.listen((String line) {
      if (!mounted) {
        return;
      }
      final bool accelUnsupported =
          line.contains('Status Code: -200431') ||
          line.contains('DAQmx_Val_Accelerometer');

      if (accelUnsupported && !_autoRecoveringAccelUnsupported) {
        unawaited(_autoFallbackToVoltageMode());
      }

      setState(() {
        if (line.startsWith('Bridge exited with code') ||
            line.startsWith('ERROR,')) {
          _isConnected = false;
        }

        _eventLogs.insert(0, '[${DateTime.now().toLocal()}] $line');
        if (_eventLogs.length > 80) {
          _eventLogs.removeRange(80, _eventLogs.length);
        }
      });
    });

    _startAcquisition();
    unawaited(_initializeStartup());
  }

  Future<void> _initializeStartup() async {
    await _loadSettings();
    if (!mounted) {
      return;
    }
    _initializeSourceOnStartup();
  }

  void _initializeSourceOnStartup() {
    _acquisitionService.setSource(
      _useBridge ? AcquisitionSource.bridge : AcquisitionSource.mock,
    );
    if (_useBridge) {
      unawaited(_toggleConnection());
      return;
    }

    _acquisitionService.setMockConnected(true);
    setState(() {
      _isConnected = true;
      _actualSampleRateHz = null;
      _actualSamplesPerRead = null;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sampleSub?.cancel();
    _statusSub?.cancel();
    _dataLogSaveDebounce?.cancel();
    _dataLoggingBlinkTimer?.cancel();
    unawaited(_finalizeDataLoggingSession());
    _stopReplayTimer();
    _syncSettingsFromInputs();
    unawaited(_saveSettings());
    unawaited(_persistRecentDataLogs());
    _bridgePathController.dispose();
    _bridgeArgsController.dispose();
    _voltageMinController.dispose();
    _voltageMaxController.dispose();
    _sampleRateController.dispose();
    _samplesPerReadController.dispose();
    _chartMinController.dispose();
    _chartMaxController.dispose();
    _accelSensitivityController.dispose();
    _waveformTimeWindowController.dispose();
    _waveformTimeWindowMinController.dispose();
    _waveformTimeWindowMaxController.dispose();
    unawaited(_acquisitionService.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _syncSettingsFromInputs();
      unawaited(_saveSettings());
    }
  }

  void _syncSettingsFromInputs() {
    _bridgeExecutablePath = _bridgePathController.text.trim();
    _bridgeArguments = _bridgeArgsController.text;
    _aiChannelMode = _extractAiModeFromArgs(_bridgeArguments);
    _bridgeArguments = _upsertBridgeFlag(
      _bridgeArguments,
      '--ai-mode',
      _aiModeFlagValue(_aiChannelMode),
    );
    final int? parsedRate = _extractIntFlagFromArgs(_bridgeArguments, '--rate');
    if (parsedRate != null && parsedRate > 0) {
      _sampleRateHz = parsedRate;
    }
    final int? parsedSamples = _extractIntFlagFromArgs(
      _bridgeArguments,
      '--samples',
    );
    if (parsedSamples != null && parsedSamples > 0) {
      _samplesPerRead = parsedSamples;
    }
    final int? sampleRate = int.tryParse(_sampleRateController.text.trim());
    if (sampleRate != null && sampleRate > 0) {
      _sampleRateHz = sampleRate;
    }
    final int? samplesPerRead = int.tryParse(
      _samplesPerReadController.text.trim(),
    );
    if (samplesPerRead != null && samplesPerRead > 0) {
      _samplesPerRead = samplesPerRead;
    }
    _bridgeArguments = _upsertBridgeFlag(
      _bridgeArguments,
      '--rate',
      _sampleRateHz.toString(),
    );
    _bridgeArguments = _upsertBridgeFlag(
      _bridgeArguments,
      '--samples',
      _samplesPerRead.toString(),
    );
    if (_aiChannelMode == BridgeAiChannelMode.accel) {
      _bridgeArguments = _upsertBridgeFlag(
        _bridgeArguments,
        '--accel-sens',
        _effectiveAccelSensitivityMvPerG().toString(),
      );
    }
    _bridgeArgsController.text = _bridgeArguments;
    _sampleRateController.text = _sampleRateHz.toString();
    _samplesPerReadController.text = _samplesPerRead.toString();
    _syncAcquisitionSignalUnit();

    final double? minVoltage = double.tryParse(
      _voltageMinController.text.trim(),
    );
    final double? maxVoltage = double.tryParse(
      _voltageMaxController.text.trim(),
    );
    if (minVoltage != null && maxVoltage != null && minVoltage < maxVoltage) {
      _voltageMin = minVoltage;
      _voltageMax = maxVoltage;
    }

    final double? minChart = double.tryParse(_chartMinController.text.trim());
    final double? maxChart = double.tryParse(_chartMaxController.text.trim());
    if (minChart != null && maxChart != null && minChart < maxChart) {
      _chartMinG = minChart;
      _chartMaxG = maxChart;

      _warningThreshold = _warningThreshold.clamp(_chartMinG, _chartMaxG);
      _dangerThreshold = _dangerThreshold.clamp(_chartMinG, _chartMaxG);
      if (_warningThreshold >= _dangerThreshold) {
        final double range = _chartMaxG - _chartMinG;
        _warningThreshold = _chartMinG + range * 0.6;
        _dangerThreshold = _chartMinG + range * 0.8;
      }
    }

    final double? minWaveMs = double.tryParse(
      _waveformTimeWindowMinController.text.trim(),
    );
    final double? maxWaveMs = double.tryParse(
      _waveformTimeWindowMaxController.text.trim(),
    );
    if (minWaveMs != null &&
        maxWaveMs != null &&
        minWaveMs > 0 &&
        maxWaveMs > minWaveMs) {
      _waveformTimeWindowMinMs = minWaveMs;
      _waveformTimeWindowMaxMs = maxWaveMs;
    }

    final double? parsedWaveWindowMs = double.tryParse(
      _waveformTimeWindowController.text.trim(),
    );
    if (parsedWaveWindowMs != null && parsedWaveWindowMs > 0) {
      _waveformTimeWindowMs = _clampWaveformTimeWindowMs(parsedWaveWindowMs);
      _waveformTimeWindowController.text = _waveformTimeWindowMs.toString();
    }
  }

  double _clampWaveformTimeWindowMs(double value) {
    if (_waveformTimeWindowMaxMs <= _waveformTimeWindowMinMs) {
      return max(1.0, value);
    }
    return value
        .clamp(_waveformTimeWindowMinMs, _waveformTimeWindowMaxMs)
        .toDouble();
  }

  String _upsertBridgeFlag(String source, String flag, String value) {
    final RegExp pattern = RegExp('${RegExp.escape(flag)}\\s+[^\\s]+');
    final String trimmed = source.trim();
    if (pattern.hasMatch(trimmed)) {
      return trimmed.replaceFirst(pattern, '$flag $value');
    }
    return '$trimmed $flag $value'.trim();
  }

  String _aiModeFlagValue(BridgeAiChannelMode mode) {
    return mode == BridgeAiChannelMode.accel ? 'accel' : 'voltage';
  }

  String _aiModeLabel(BridgeAiChannelMode mode) {
    return mode == BridgeAiChannelMode.accel
        ? 'DAQmxCreateAIAccelChan'
        : 'DAQmxCreateAIVoltageChan';
  }

  String _bridgeRawUnitLabel() {
    return _aiChannelMode == BridgeAiChannelMode.accel ? 'g' : 'V';
  }

  int? _extractIntFlagFromArgs(String args, String flag) {
    final RegExp pattern = RegExp('${RegExp.escape(flag)}\\s+(-?\\d+)');
    final Match? match = pattern.firstMatch(args);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1)!);
  }

  double? _extractDoubleFlagFromArgs(String args, String flag) {
    final RegExp pattern = RegExp(
      '${RegExp.escape(flag)}\\s+(-?\\d+(?:\\.\\d+)?)',
    );
    final Match? match = pattern.firstMatch(args);
    if (match == null) {
      return null;
    }
    return double.tryParse(match.group(1)!);
  }

  void _applyBridgePreset(String args, String label) {
    setState(() {
      _bridgeArguments = args.trim();
      _bridgeArgsController.text = _bridgeArguments;
      _aiChannelMode = _extractAiModeFromArgs(_bridgeArguments);

      final int? parsedRate = _extractIntFlagFromArgs(
        _bridgeArguments,
        '--rate',
      );
      final int? parsedSamples = _extractIntFlagFromArgs(
        _bridgeArguments,
        '--samples',
      );
      final double? parsedMin = _extractDoubleFlagFromArgs(
        _bridgeArguments,
        '--min',
      );
      final double? parsedMax = _extractDoubleFlagFromArgs(
        _bridgeArguments,
        '--max',
      );

      if (parsedRate != null && parsedRate > 0) {
        _sampleRateHz = parsedRate;
        _sampleRateController.text = parsedRate.toString();
      }
      if (parsedSamples != null && parsedSamples > 0) {
        _samplesPerRead = parsedSamples;
        _samplesPerReadController.text = parsedSamples.toString();
      }
      if (parsedMin != null && parsedMax != null && parsedMin < parsedMax) {
        _voltageMin = parsedMin;
        _voltageMax = parsedMax;
        _voltageMinController.text = parsedMin.toString();
        _voltageMaxController.text = parsedMax.toString();
      }

      _eventLogs.insert(
        0,
        '[${DateTime.now().toLocal()}] Applied bridge preset: $label',
      );
      _trimLogs();
    });

    _syncAcquisitionSignalUnit();
    unawaited(_saveSettings());
  }

  _AccelSensorPreset _selectedAccelPreset() {
    return _accelPresets.firstWhere(
      (_AccelSensorPreset preset) => preset.id == _selectedAccelPresetId,
      orElse: () => _accelPresets.first,
    );
  }

  double _effectiveAccelSensitivityMvPerG() {
    final _AccelSensorPreset preset = _selectedAccelPreset();
    if (preset.isCustom) {
      return _customAccelSensitivityMvPerG;
    }
    return preset.sensitivityMvPerG;
  }

  void _syncAcquisitionSignalUnit() {
    _acquisitionService.setBridgeSignalUnit(
      _aiChannelMode == BridgeAiChannelMode.accel
          ? BridgeSignalUnit.accelerationG
          : BridgeSignalUnit.voltage,
    );
  }

  void _applyAccelPresetAndSensitivity() {
    final _AccelSensorPreset preset = _selectedAccelPreset();
    double sensitivity = _customAccelSensitivityMvPerG;

    if (preset.isCustom) {
      final double? parsed = double.tryParse(
        _accelSensitivityController.text.trim(),
      );
      if (parsed == null || parsed <= 0) {
        setState(() {
          _eventLogs.insert(
            0,
            '[${DateTime.now().toLocal()}] Invalid custom sensitivity. Use value > 0 (mV/g).',
          );
          _trimLogs();
        });
        return;
      }
      sensitivity = parsed;
    } else {
      sensitivity = preset.sensitivityMvPerG;
      _accelSensitivityController.text = sensitivity.toString();
    }

    setState(() {
      _customAccelSensitivityMvPerG = sensitivity;
      _aiChannelMode = BridgeAiChannelMode.accel;
      _bridgeArguments = _upsertBridgeFlag(
        _bridgeArguments,
        '--ai-mode',
        'accel',
      );
      _bridgeArguments = _upsertBridgeFlag(
        _bridgeArguments,
        '--accel-sens',
        sensitivity.toString(),
      );
      _bridgeArgsController.text = _bridgeArguments;
      _eventLogs.insert(
        0,
        '[${DateTime.now().toLocal()}] Accelerometer preset applied: ${preset.label}, sensitivity ${sensitivity.toStringAsFixed(2)} mV/g',
      );
      _trimLogs();
    });

    _syncAcquisitionSignalUnit();
    unawaited(_saveSettings());
  }

  Future<void> _autoFallbackToVoltageMode() async {
    if (!mounted ||
        !_useBridge ||
        _aiChannelMode != BridgeAiChannelMode.accel) {
      return;
    }

    _autoRecoveringAccelUnsupported = true;

    setState(() {
      _aiChannelMode = BridgeAiChannelMode.voltage;
      _bridgeArguments = _upsertBridgeFlag(
        _bridgeArguments,
        '--ai-mode',
        'voltage',
      );
      _bridgeArgsController.text = _bridgeArguments;
      _lastAutoFallbackAt = DateTime.now();
      _lastAutoFallbackReason =
          'Current channel does not support accelerometer measurement type.';
      _eventLogs.insert(
        0,
        '[${DateTime.now().toLocal()}] Auto fallback: channel does not support accelerometer mode. Switching to voltage mode and reconnecting.',
      );
      _trimLogs();
    });
    _syncAcquisitionSignalUnit();
    await _saveSettings();

    try {
      await _disconnectConnection(
        reason: 'auto fallback from accel unsupported',
      );
      await _connectConnection(trigger: 'auto fallback to voltage mode');
    } finally {
      _autoRecoveringAccelUnsupported = false;
    }
  }

  BridgeAiChannelMode _parseAiChannelMode(String? raw) {
    if (raw == null) {
      return BridgeAiChannelMode.voltage;
    }
    final String normalized = raw.trim().toLowerCase();
    if (normalized == 'accel' || normalized == 'acceleration') {
      return BridgeAiChannelMode.accel;
    }
    return BridgeAiChannelMode.voltage;
  }

  BridgeAiChannelMode _extractAiModeFromArgs(String args) {
    final RegExp pattern = RegExp(r'--ai-mode\s+([^\s]+)');
    final Match? match = pattern.firstMatch(args);
    if (match == null) {
      return BridgeAiChannelMode.voltage;
    }
    return _parseAiChannelMode(match.group(1));
  }

  void _applyAiChannelMode() {
    setState(() {
      _bridgeArguments = _upsertBridgeFlag(
        _bridgeArguments,
        '--ai-mode',
        _aiModeFlagValue(_aiChannelMode),
      );
      if (_aiChannelMode == BridgeAiChannelMode.accel) {
        _bridgeArguments = _upsertBridgeFlag(
          _bridgeArguments,
          '--accel-sens',
          _effectiveAccelSensitivityMvPerG().toString(),
        );
      }
      _bridgeArgsController.text = _bridgeArguments;
      _eventLogs.insert(
        0,
        '[${DateTime.now().toLocal()}] AI channel mode updated: ${_aiModeLabel(_aiChannelMode)}',
      );
      _trimLogs();
    });
    _syncAcquisitionSignalUnit();
    unawaited(_saveSettings());
  }

  Future<void> _loadSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? savedPath = prefs.getString(_prefBridgePath);
    final String? savedArgs = prefs.getString(_prefBridgeArgs);
    final double? savedMin = prefs.getDouble(_prefVoltageMin);
    final double? savedMax = prefs.getDouble(_prefVoltageMax);
    final bool? savedUseBridge = prefs.getBool(_prefUseBridge);
    final double? savedChartMin = prefs.getDouble(_prefChartMinG);
    final double? savedChartMax = prefs.getDouble(_prefChartMaxG);
    final double? savedWaveWindow = prefs.getDouble(_prefWaveformTimeWindowMs);
    final double? savedWaveMin = prefs.getDouble(_prefWaveformTimeWindowMinMs);
    final double? savedWaveMax = prefs.getDouble(_prefWaveformTimeWindowMaxMs);
    final String? savedAiMode = prefs.getString(_prefAiChannelMode);
    final String? savedAccelPresetId = prefs.getString(_prefAccelPresetId);
    final int? savedSampleRateHz = prefs.getInt(_prefSampleRateHz);
    final int? savedSamplesPerRead = prefs.getInt(_prefSamplesPerRead);
    final double? savedAccelSensitivity = prefs.getDouble(
      _prefAccelSensitivityMvPerG,
    );
    final String? savedLastAutoFallbackAtIso = prefs.getString(
      _prefLastAutoFallbackAt,
    );
    final String? savedLastAutoFallbackReason = prefs.getString(
      _prefLastAutoFallbackReason,
    );
    final bool? savedDataLoggingEnabled = prefs.getBool(
      _prefDataLoggingEnabled,
    );
    final List<String> savedLoggedSamples =
        prefs.getStringList(_prefRecentLoggedSamples) ?? const <String>[];

    if (!mounted) {
      return;
    }

    setState(() {
      if (savedPath != null && savedPath.trim().isNotEmpty) {
        _bridgeExecutablePath = savedPath;
      }
      if (savedArgs != null && savedArgs.trim().isNotEmpty) {
        _bridgeArguments = savedArgs;
      }
      if (savedMin != null) {
        _voltageMin = savedMin;
      }
      if (savedMax != null) {
        _voltageMax = savedMax;
      }
      if (savedUseBridge != null) {
        _useBridge = savedUseBridge;
      }
      if (savedChartMin != null) {
        _chartMinG = savedChartMin;
      }
      if (savedChartMax != null) {
        _chartMaxG = savedChartMax;
      }
      if (savedWaveMin != null && savedWaveMin > 0) {
        _waveformTimeWindowMinMs = savedWaveMin;
      }
      if (savedWaveMax != null && savedWaveMax > 0) {
        _waveformTimeWindowMaxMs = savedWaveMax;
      }
      if (_waveformTimeWindowMaxMs <= _waveformTimeWindowMinMs) {
        _waveformTimeWindowMinMs = 20.0;
        _waveformTimeWindowMaxMs = 2000.0;
      }
      if (savedWaveWindow != null && savedWaveWindow > 0) {
        _waveformTimeWindowMs = _clampWaveformTimeWindowMs(savedWaveWindow);
      } else {
        _waveformTimeWindowMs = _clampWaveformTimeWindowMs(
          _waveformTimeWindowMs,
        );
      }
      if (_chartMaxG <= _chartMinG) {
        _chartMinG = 0.0;
        _chartMaxG = 1.2;
      }
      // Clamp thresholds to the loaded chart range to avoid Slider assertion
      _warningThreshold = _warningThreshold.clamp(_chartMinG, _chartMaxG);
      _dangerThreshold = _dangerThreshold.clamp(_chartMinG, _chartMaxG);
      if (_warningThreshold >= _dangerThreshold) {
        _warningThreshold = (_dangerThreshold - 0.01).clamp(
          _chartMinG,
          _chartMaxG,
        );
      }
      if (savedAccelPresetId != null &&
          _accelPresets.any(
            (_AccelSensorPreset preset) => preset.id == savedAccelPresetId,
          )) {
        _selectedAccelPresetId = savedAccelPresetId;
      }
      if (savedAccelSensitivity != null && savedAccelSensitivity > 0) {
        _customAccelSensitivityMvPerG = savedAccelSensitivity;
      }
      if (savedLastAutoFallbackAtIso != null &&
          savedLastAutoFallbackAtIso.isNotEmpty) {
        _lastAutoFallbackAt = DateTime.tryParse(savedLastAutoFallbackAtIso);
      }
      if (savedLastAutoFallbackReason != null) {
        _lastAutoFallbackReason = savedLastAutoFallbackReason;
      }
      if (savedDataLoggingEnabled != null) {
        _dataLoggingEnabled = savedDataLoggingEnabled;
      }
      _dataLogs
        ..clear()
        ..addAll(
          savedLoggedSamples
              .map(_LoggedSample.fromJsonString)
              .whereType<_LoggedSample>()
              .toList(),
        );
      if (_dataLogs.length > _maxRecentDataLogs) {
        _dataLogs.removeRange(_maxRecentDataLogs, _dataLogs.length);
      }

      if (_dataLoggingEnabled) {
        unawaited(_startDataLoggingSession());
      } else {
        unawaited(_finalizeDataLoggingSession());
      }

      _syncDataLoggingBlinkTimer();

      _aiChannelMode = savedAiMode != null
          ? _parseAiChannelMode(savedAiMode)
          : _extractAiModeFromArgs(_bridgeArguments);
      final int? rateInArgs = _extractIntFlagFromArgs(
        _bridgeArguments,
        '--rate',
      );
      final int? samplesInArgs = _extractIntFlagFromArgs(
        _bridgeArguments,
        '--samples',
      );
      if (savedSampleRateHz != null && savedSampleRateHz > 0) {
        _sampleRateHz = savedSampleRateHz;
      } else if (rateInArgs != null && rateInArgs > 0) {
        _sampleRateHz = rateInArgs;
      }
      if (savedSamplesPerRead != null && savedSamplesPerRead > 0) {
        _samplesPerRead = savedSamplesPerRead;
      } else if (samplesInArgs != null && samplesInArgs > 0) {
        _samplesPerRead = samplesInArgs;
      }
      _bridgeArguments = _upsertBridgeFlag(
        _bridgeArguments,
        '--rate',
        _sampleRateHz.toString(),
      );
      _bridgeArguments = _upsertBridgeFlag(
        _bridgeArguments,
        '--samples',
        _samplesPerRead.toString(),
      );
      _bridgeArguments = _upsertBridgeFlag(
        _bridgeArguments,
        '--ai-mode',
        _aiModeFlagValue(_aiChannelMode),
      );
      if (_aiChannelMode == BridgeAiChannelMode.accel) {
        _bridgeArguments = _upsertBridgeFlag(
          _bridgeArguments,
          '--accel-sens',
          _effectiveAccelSensitivityMvPerG().toString(),
        );
      }

      _bridgePathController.text = _bridgeExecutablePath;
      _bridgeArgsController.text = _bridgeArguments;
      _voltageMinController.text = _voltageMin.toString();
      _voltageMaxController.text = _voltageMax.toString();
      _sampleRateController.text = _sampleRateHz.toString();
      _samplesPerReadController.text = _samplesPerRead.toString();
      _chartMinController.text = _chartMinG.toString();
      _chartMaxController.text = _chartMaxG.toString();
      _waveformTimeWindowController.text = _waveformTimeWindowMs.toString();
      _waveformTimeWindowMinController.text = _waveformTimeWindowMinMs
          .toString();
      _waveformTimeWindowMaxController.text = _waveformTimeWindowMaxMs
          .toString();
      _accelSensitivityController.text = _customAccelSensitivityMvPerG
          .toString();
    });

    _syncAcquisitionSignalUnit();
  }

  Future<void> _saveSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefBridgePath, _bridgeExecutablePath);
    await prefs.setString(_prefBridgeArgs, _bridgeArguments);
    await prefs.setDouble(_prefVoltageMin, _voltageMin);
    await prefs.setDouble(_prefVoltageMax, _voltageMax);
    await prefs.setBool(_prefUseBridge, _useBridge);
    await prefs.setDouble(_prefChartMinG, _chartMinG);
    await prefs.setDouble(_prefChartMaxG, _chartMaxG);
    await prefs.setDouble(_prefWaveformTimeWindowMs, _waveformTimeWindowMs);
    await prefs.setDouble(
      _prefWaveformTimeWindowMinMs,
      _waveformTimeWindowMinMs,
    );
    await prefs.setDouble(
      _prefWaveformTimeWindowMaxMs,
      _waveformTimeWindowMaxMs,
    );
    await prefs.setInt(_prefSampleRateHz, _sampleRateHz);
    await prefs.setInt(_prefSamplesPerRead, _samplesPerRead);
    await prefs.setString(_prefAiChannelMode, _aiModeFlagValue(_aiChannelMode));
    await prefs.setString(_prefAccelPresetId, _selectedAccelPresetId);
    await prefs.setBool(_prefDataLoggingEnabled, _dataLoggingEnabled);
    await prefs.setDouble(
      _prefAccelSensitivityMvPerG,
      _customAccelSensitivityMvPerG,
    );
    if (_lastAutoFallbackAt != null) {
      await prefs.setString(
        _prefLastAutoFallbackAt,
        _lastAutoFallbackAt!.toIso8601String(),
      );
    } else {
      await prefs.remove(_prefLastAutoFallbackAt);
    }
    await prefs.setString(_prefLastAutoFallbackReason, _lastAutoFallbackReason);
  }

  Future<Directory> _ensureDataLogDirectory() async {
    final Directory? cached = _dataLogDirectory;
    if (cached != null) {
      return cached;
    }

    final Directory baseDir = await getApplicationSupportDirectory();
    final Directory logDir = Directory(
      '${baseDir.path}${Platform.pathSeparator}data_logs',
    );
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    _dataLogDirectory = logDir;
    return logDir;
  }

  String _dataLogFileName(DateTime timestamp) {
    final DateTime localTime = timestamp.toLocal();
    final String year = localTime.year.toString().padLeft(4, '0');
    final String month = localTime.month.toString().padLeft(2, '0');
    final String day = localTime.day.toString().padLeft(2, '0');
    final String hour = localTime.hour.toString().padLeft(2, '0');
    final String minute = localTime.minute.toString().padLeft(2, '0');
    final String second = localTime.second.toString().padLeft(2, '0');
    final String timePart = <String>[hour, 'h', minute, 'm', second].join();
    return 'samples_$year-$month-$day-$timePart.$_binaryLogExtension';
  }

  Future<File> _ensureCurrentDataLogFile(DateTime timestamp) async {
    final Directory logDir = await _ensureDataLogDirectory();
    final File file = File(
      '${logDir.path}${Platform.pathSeparator}${_dataLogFileName(timestamp)}',
    );
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    return file;
  }

  Future<void> _ensureBinaryLogHeader() async {
    final RandomAccessFile? sink = _dataLoggingSessionSink;
    if (sink == null) {
      return;
    }

    final int currentLength = await sink.length();
    if (currentLength > 0) {
      await sink.setPosition(currentLength);
      return;
    }

    final ByteData header = ByteData(_binaryLogHeaderSize);
    for (int i = 0; i < _binaryLogMagic.length; i++) {
      header.setUint8(i, _binaryLogMagic.codeUnitAt(i));
    }
    header.setUint16(8, _channels.length, Endian.little);
    // 0 means variable-size records (sample + optional wave/fft payload bytes).
    header.setUint16(10, 0, Endian.little);
    // V3 header layout:
    // [12..19] indexOffset (u64), [20..23] indexCount (u32),
    // [24..27] indexStride (u32), [28..31] reserved flags.
    header.setUint64(12, 0, Endian.little);
    header.setUint32(20, 0, Endian.little);
    header.setUint32(24, _binaryIndexStride, Endian.little);
    header.setUint32(28, 0, Endian.little);
    await sink.writeFrom(header.buffer.asUint8List());
    await sink.flush();
  }

  Future<void> _writeBinaryIndexAndPatchHeader(RandomAccessFile sink) async {
    final int indexOffset = await sink.position();
    final int entryCount = _dataLogTimeIndex.length;

    final ByteData idxHeader = ByteData(_binaryIndexHeaderSize);
    for (int i = 0; i < _binaryIndexMagic.length; i++) {
      idxHeader.setUint8(i, _binaryIndexMagic.codeUnitAt(i));
    }
    idxHeader.setUint32(8, entryCount, Endian.little);
    idxHeader.setUint32(12, _binaryIndexStride, Endian.little);
    await sink.writeFrom(idxHeader.buffer.asUint8List());

    final Uint8List entryBytes = Uint8List(_binaryIndexEntrySize);
    final ByteData entryData = ByteData.sublistView(entryBytes);
    for (final _BinaryTimeIndexEntry entry in _dataLogTimeIndex) {
      entryData.setInt64(0, entry.timestampMsUtc, Endian.little);
      entryData.setInt64(8, entry.byteOffset, Endian.little);
      await sink.writeFrom(entryBytes);
    }

    final ByteData patch = ByteData(20);
    patch.setUint64(0, indexOffset, Endian.little);
    patch.setUint32(8, entryCount, Endian.little);
    patch.setUint32(12, _binaryIndexStride, Endian.little);
    patch.setUint32(16, 0, Endian.little);
    await sink.setPosition(12);
    await sink.writeFrom(patch.buffer.asUint8List());
    await sink.setPosition(await sink.length());
  }

  Uint8List _encodeBinaryLogRecord(_LoggedSample sample) {
    final List<int> waveBytes = _encodePayloadBytes(sample.wavePayloadJson);
    final List<int> fftBytes = _encodePayloadBytes(sample.fftPayloadJson);
    final int channelCount = _channels.length;
    final int fixedSize = 8 + 4 + 4 + (channelCount * 4) + 4 + 4;
    final int recordSize = fixedSize + waveBytes.length + fftBytes.length;
    final ByteData data = ByteData(recordSize);

    data.setInt64(
      0,
      sample.timestamp.toUtc().millisecondsSinceEpoch,
      Endian.little,
    );
    data.setInt32(8, sample.sampleRateHz ?? -1, Endian.little);
    data.setInt32(12, sample.samplesRead ?? -1, Endian.little);

    for (int i = 0; i < channelCount; i++) {
      final String channel = _channels[i];
      final double? value = sample.values[channel];
      data.setFloat32(16 + (i * 4), value ?? double.nan, Endian.little);
    }

    final int lensOffset = 16 + (channelCount * 4);
    data.setUint32(lensOffset, waveBytes.length, Endian.little);
    data.setUint32(lensOffset + 4, fftBytes.length, Endian.little);

    final Uint8List out = data.buffer.asUint8List();
    int payloadOffset = lensOffset + 8;
    if (waveBytes.isNotEmpty) {
      out.setRange(payloadOffset, payloadOffset + waveBytes.length, waveBytes);
      payloadOffset += waveBytes.length;
    }
    if (fftBytes.isNotEmpty) {
      out.setRange(payloadOffset, payloadOffset + fftBytes.length, fftBytes);
    }

    return out;
  }

  List<int> _encodePayloadBytes(String? payloadJson) {
    if (payloadJson == null) {
      return const <int>[];
    }
    final String text = payloadJson.trim();
    if (text.isEmpty) {
      return const <int>[];
    }
    return utf8.encode(text);
  }

  String? _decodePayloadBytes(Uint8List payloadBytes) {
    if (payloadBytes.isEmpty) {
      return null;
    }
    final String plain = utf8.decode(payloadBytes, allowMalformed: true).trim();
    return plain.isEmpty ? null : plain;
  }

  Future<_BinaryReplayLoadResult> _loadReplaySamplesFromBinary(
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    final RandomAccessFile raf = await file.open(mode: FileMode.read);
    try {
      onProgress?.call(0.0);
      final int fileLength = await raf.length();
      if (fileLength < _binaryLogHeaderSize) {
        throw const FormatException(
          'File log quá nhỏ hoặc không đúng định dạng binary.',
        );
      }

      await raf.setPosition(0);
      final Uint8List headerBytes = await raf.read(_binaryLogHeaderSize);
      if (headerBytes.length != _binaryLogHeaderSize) {
        throw const FormatException('Không thể đọc header file log binary.');
      }

      final ByteData header = ByteData.sublistView(headerBytes);
      final String magic = String.fromCharCodes(headerBytes.sublist(0, 8));
      if (magic != _binaryLogMagic) {
        throw const FormatException(
          'Sai magic header. Đây không phải file replay binary hợp lệ.',
        );
      }

      final int channelCount = header.getUint16(8, Endian.little);
      final int recordSize = header.getUint16(10, Endian.little);
      final bool isVariableRecord = recordSize == 0;
      final int fixedRecordSize = 8 + 4 + 4 + (channelCount * 4);
      final int fixedWithLengths = fixedRecordSize + 8;
      if (channelCount <= 0 ||
          (!isVariableRecord && recordSize != fixedRecordSize)) {
        throw const FormatException(
          'Header binary không hợp lệ (channelCount/recordSize).',
        );
      }

      int dataEndOffset = fileLength;
      int loadedIndexStride = _binaryIndexStride;
      final List<_BinaryTimeIndexEntry> loadedTimeIndex =
          <_BinaryTimeIndexEntry>[];
      if (header.lengthInBytes >= 32) {
        final int indexOffset = header.getUint64(12, Endian.little);
        final int indexCountFromHeader = header.getUint32(20, Endian.little);
        final int indexStrideFromHeader = header.getUint32(24, Endian.little);
        if (indexOffset > _binaryLogHeaderSize && indexOffset < fileLength) {
          dataEndOffset = indexOffset;
          await raf.setPosition(indexOffset);
          final Uint8List idxHeaderBytes = await raf.read(
            _binaryIndexHeaderSize,
          );
          if (idxHeaderBytes.length == _binaryIndexHeaderSize) {
            final String idxMagic = String.fromCharCodes(
              idxHeaderBytes.sublist(0, 8),
            );
            if (idxMagic == _binaryIndexMagic) {
              final ByteData idxHeader = ByteData.sublistView(idxHeaderBytes);
              final int indexCount = idxHeader.getUint32(8, Endian.little);
              final int indexStride = idxHeader.getUint32(12, Endian.little);
              final int safeStride = indexStride > 0
                  ? indexStride
                  : (indexStrideFromHeader > 0
                        ? indexStrideFromHeader
                        : _binaryIndexStride);
              loadedIndexStride = safeStride;
              final int expectedCount = indexCountFromHeader > 0
                  ? min(indexCount, indexCountFromHeader)
                  : indexCount;
              for (int i = 0; i < expectedCount; i++) {
                final Uint8List entryBytes = await raf.read(
                  _binaryIndexEntrySize,
                );
                if (entryBytes.length != _binaryIndexEntrySize) {
                  break;
                }
                final ByteData entry = ByteData.sublistView(entryBytes);
                loadedTimeIndex.add(
                  _BinaryTimeIndexEntry(
                    timestampMsUtc: entry.getInt64(0, Endian.little),
                    byteOffset: entry.getInt64(8, Endian.little),
                    sampleIndex: i * safeStride,
                  ),
                );
              }
            }
          }
        }
      }
      onProgress?.call(0.05);

      final List<String> activeChannels = channelCount == _channels.length
          ? _channels
          : List<String>.generate(channelCount, (int index) => 'AI$index');
      final List<_LoggedSample> samples = <_LoggedSample>[];
      int sampleIndex = 0;

      await raf.setPosition(_binaryLogHeaderSize);
      int lastProgressPos = _binaryLogHeaderSize;
      while (true) {
        final int currentPos = await raf.position();
        final int minRecordSize = isVariableRecord
            ? fixedWithLengths
            : fixedRecordSize;
        if (currentPos + minRecordSize > dataEndOffset) {
          break;
        }

        final Uint8List baseBytes = await raf.read(minRecordSize);
        if (baseBytes.length != minRecordSize) {
          break;
        }
        final ByteData base = ByteData.sublistView(baseBytes);
        final int timestampMsUtc = base.getInt64(0, Endian.little);
        final int sampleRateHz = base.getInt32(8, Endian.little);
        final int samplesRead = base.getInt32(12, Endian.little);

        final Map<String, double> values = <String, double>{};
        for (int i = 0; i < activeChannels.length; i++) {
          final double v = base.getFloat32(16 + (i * 4), Endian.little);
          if (!v.isNaN) {
            values[activeChannels[i]] = v;
          }
        }

        Uint8List? wavePayloadBytes;
        Uint8List? fftPayloadBytes;
        if (isVariableRecord) {
          final int lensOffset = 16 + (channelCount * 4);
          final int waveLen = base.getUint32(lensOffset, Endian.little);
          final int fftLen = base.getUint32(lensOffset + 4, Endian.little);
          final int payloadBytes = waveLen + fftLen;
          if (payloadBytes > 0) {
            final int payloadPos = await raf.position();
            if (payloadPos + payloadBytes > dataEndOffset) {
              break;
            }
            final Uint8List payload = await raf.read(payloadBytes);
            if (payload.length != payloadBytes) {
              break;
            }
            if (waveLen > 0) {
              wavePayloadBytes = Uint8List.fromList(
                payload.sublist(0, waveLen),
              );
            }
            if (fftLen > 0) {
              fftPayloadBytes = Uint8List.fromList(
                payload.sublist(waveLen, waveLen + fftLen),
              );
            }
          }
        }

        if (values.isNotEmpty) {
          samples.add(
            _LoggedSample(
              timestamp: DateTime.fromMillisecondsSinceEpoch(
                timestampMsUtc,
                isUtc: true,
              ).toLocal(),
              values: values,
              sampleRateHz: sampleRateHz > 0 ? sampleRateHz : null,
              samplesRead: samplesRead > 0 ? samplesRead : null,
              wavePayloadBytes: wavePayloadBytes,
              fftPayloadBytes: fftPayloadBytes,
            ),
          );
          if (loadedTimeIndex.isEmpty &&
              (sampleIndex == 0 || sampleIndex % _binaryIndexStride == 0)) {
            loadedTimeIndex.add(
              _BinaryTimeIndexEntry(
                timestampMsUtc: timestampMsUtc,
                byteOffset: currentPos,
                sampleIndex: sampleIndex,
              ),
            );
            loadedIndexStride = _binaryIndexStride;
          }
          sampleIndex += 1;
        }

        if (currentPos - lastProgressPos >= 262144) {
          lastProgressPos = currentPos;
          final double p = (currentPos / max(1, dataEndOffset))
              .clamp(0.0, 1.0)
              .toDouble();
          onProgress?.call(p);
        }
      }

      onProgress?.call(1.0);

      return _BinaryReplayLoadResult(
        samples: samples,
        timeIndex: loadedTimeIndex,
        indexStride: max(1, loadedIndexStride),
      );
    } finally {
      await raf.close();
    }
  }

  String? _buildWavePayloadJsonForLog() {
    if (_bridgeWaveSampleRateHz <= 0 ||
        !_isPayloadFresh(_bridgeWaveCapturedAt)) {
      return null;
    }
    final Map<String, List<double>> channels = <String, List<double>>{};
    for (final String channel in _channels) {
      final List<double>? samples = _bridgeWaveSamples[channel];
      if (samples == null || samples.isEmpty) {
        continue;
      }
      channels[channel] = List<double>.from(samples);
    }
    if (channels.isEmpty) {
      return null;
    }
    return jsonEncode(<String, Object?>{
      'sampleRateHz': _bridgeWaveSampleRateHz,
      'decimStep': _bridgeWaveDecimStep,
      'capturedAtUtc': _bridgeWaveCapturedAt!.toUtc().toIso8601String(),
      'unit': _bridgeRawUnitLabel(),
      'channels': channels,
    });
  }

  String? _buildFftPayloadJsonForLog() {
    if (_bridgeFftSampleRateHz <= 0 ||
        _bridgeFftBinCount <= 0 ||
        !_isPayloadFresh(_bridgeFftCapturedAt)) {
      return null;
    }
    final Map<String, List<double>> channels = <String, List<double>>{};
    for (final String channel in _channels) {
      final List<double>? mags = _bridgeFftMags[channel];
      if (mags == null || mags.isEmpty) {
        continue;
      }
      channels[channel] = List<double>.from(mags);
    }
    if (channels.isEmpty) {
      return null;
    }
    return jsonEncode(<String, Object?>{
      'sampleRateHz': _bridgeFftSampleRateHz,
      'samplesRead': _bridgeFftSamplesRead,
      'binCount': _bridgeFftBinCount,
      'capturedAtUtc': _bridgeFftCapturedAt!.toUtc().toIso8601String(),
      'channels': channels,
    });
  }

  int _payloadFreshnessWindowMs() {
    final int sampleRate = _actualSampleRateHz ?? _sampleRateHz;
    final int samplesPerRead = _actualSamplesPerRead ?? _samplesPerRead;
    if (sampleRate <= 0 || samplesPerRead <= 0) {
      return 500;
    }
    final int blockMs = ((samplesPerRead * 1000) / sampleRate).round();
    return max(300, blockMs * 2);
  }

  bool _isPayloadFresh(DateTime? capturedAt) {
    if (capturedAt == null) {
      return false;
    }
    return DateTime.now().difference(capturedAt).inMilliseconds <=
        _payloadFreshnessWindowMs();
  }

  Future<void> _startDataLoggingSession({DateTime? startedAt}) async {
    final DateTime sessionStartAt = (startedAt ?? DateTime.now()).toLocal();
    _dataLoggingSessionStartAt ??= sessionStartAt;
    final File file = await _ensureCurrentDataLogFile(
      _dataLoggingSessionStartAt!,
    );
    _dataLoggingSessionFile = file;
    _dataLoggingSessionSink ??= await file.open(mode: FileMode.append);
    _dataLogTimeIndex.clear();
    _dataLogRecordCount = 0;
    await _ensureBinaryLogHeader();
  }

  Future<void> _finalizeDataLoggingSession() async {
    final DateTime? sessionStartAt = _dataLoggingSessionStartAt;
    final File? sessionFile = _dataLoggingSessionFile;
    final RandomAccessFile? sessionSink = _dataLoggingSessionSink;
    _dataLoggingSessionStartAt = null;
    _dataLoggingSessionFile = null;
    _dataLoggingSessionSink = null;

    if (sessionStartAt == null || sessionFile == null) {
      await sessionSink?.close();
      _dataLogTimeIndex.clear();
      _dataLogRecordCount = 0;
      return;
    }

    if (sessionSink != null && _dataLogTimeIndex.isNotEmpty) {
      await _writeBinaryIndexAndPatchHeader(sessionSink);
    }

    await sessionSink?.flush();
    await sessionSink?.close();
    _dataLogTimeIndex.clear();
    _dataLogRecordCount = 0;
  }

  Future<void> _appendDataLogToArchive(_LoggedSample sample) async {
    DateTime sessionStartAt =
        _dataLoggingSessionStartAt ?? sample.timestamp.toLocal();
    if (sample.timestamp.toLocal().difference(sessionStartAt) >=
        _binaryLogRotateEvery) {
      await _finalizeDataLoggingSession();
      sessionStartAt = sample.timestamp.toLocal();
      _dataLoggingSessionStartAt = sessionStartAt;
    }

    _dataLoggingSessionStartAt ??= sessionStartAt;
    final File file = await _ensureCurrentDataLogFile(sessionStartAt);
    _dataLoggingSessionFile ??= file;
    _dataLoggingSessionSink ??= await file.open(mode: FileMode.append);
    await _ensureBinaryLogHeader();
    final int offsetBeforeWrite = await _dataLoggingSessionSink!.position();
    final Uint8List record = _encodeBinaryLogRecord(sample);
    await _dataLoggingSessionSink!.writeFrom(record);

    if (_dataLogRecordCount == 0 ||
        _dataLogRecordCount % _binaryIndexStride == 0) {
      _dataLogTimeIndex.add(
        _BinaryTimeIndexEntry(
          timestampMsUtc: sample.timestamp.toUtc().millisecondsSinceEpoch,
          byteOffset: offsetBeforeWrite,
          sampleIndex: _dataLogRecordCount,
        ),
      );
    }
    _dataLogRecordCount += 1;
  }

  void _appendDataLog(AcquisitionSample sample) {
    if (!_dataLoggingEnabled || sample.values.isEmpty) {
      return;
    }

    final _LoggedSample loggedSample = _LoggedSample(
      timestamp: DateTime.now(),
      values: Map<String, double>.from(sample.values),
      sampleRateHz: sample.sampleRateHz,
      samplesRead: sample.samplesRead,
      wavePayloadJson: _buildWavePayloadJsonForLog(),
      fftPayloadJson: _buildFftPayloadJsonForLog(),
    );

    _dataLogs.insert(0, loggedSample);

    if (_dataLogs.length > _maxRecentDataLogs) {
      _dataLogs.removeRange(_maxRecentDataLogs, _dataLogs.length);
    }

    _schedulePersistDataLogs();
    unawaited(_appendDataLogToArchive(loggedSample));
  }

  void _schedulePersistDataLogs() {
    _dataLogSaveDebounce?.cancel();
    _dataLogSaveDebounce = Timer(const Duration(seconds: 1), () {
      unawaited(_persistRecentDataLogs());
    });
  }

  Future<void> _persistRecentDataLogs({SharedPreferences? prefs}) async {
    final SharedPreferences resolvedPrefs =
        prefs ?? await SharedPreferences.getInstance();
    final List<String> encoded = _dataLogs
        .map((_LoggedSample sample) => jsonEncode(sample.toJson()))
        .toList(growable: false);
    await resolvedPrefs.setStringList(_prefRecentLoggedSamples, encoded);
  }

  String _fileNameFromPath(String path) {
    final List<String> parts = path.split(RegExp(r'[\\/]'));
    return parts.isEmpty ? path : parts.last;
  }

  void _clearReplayHistory() {
    for (final String channel in _channels) {
      _replayHistory[channel]!.clear();
    }
  }

  void _stopReplayTimer() {
    _replayTimer?.cancel();
    _replayTimer = null;
  }

  double _replayTotalDurationMs() {
    if (_replaySamples.length < 2) {
      return 0;
    }
    return _replaySamples.last.timestamp
        .difference(_replaySamples.first.timestamp)
        .inMilliseconds
        .toDouble();
  }

  int _replayIndexForPositionMs(double positionMs) {
    if (_replaySamples.isEmpty) {
      return -1;
    }

    final int baseMs = _replaySamples.first.timestamp.millisecondsSinceEpoch;
    final int targetMs = baseMs + positionMs.round();
    int low = 0;
    int high = _replaySamples.length - 1;

    if (_replayTimeIndex.length >= 2) {
      int idxLow = 0;
      int idxHigh = _replayTimeIndex.length - 1;
      int idxResult = 0;
      while (idxLow <= idxHigh) {
        final int mid = idxLow + ((idxHigh - idxLow) >> 1);
        if (_replayTimeIndex[mid].timestampMsUtc <= targetMs) {
          idxResult = mid;
          idxLow = mid + 1;
        } else {
          idxHigh = mid - 1;
        }
      }

      final _BinaryTimeIndexEntry lowerEntry = _replayTimeIndex[idxResult];
      low = lowerEntry.sampleIndex.clamp(0, _replaySamples.length - 1);
      if (idxResult + 1 < _replayTimeIndex.length) {
        final _BinaryTimeIndexEntry upperEntry =
            _replayTimeIndex[idxResult + 1];
        high = (upperEntry.sampleIndex + _replayIndexStride).clamp(
          low,
          _replaySamples.length - 1,
        );
      }
    }

    int result = -1;

    while (low <= high) {
      final int mid = low + ((high - low) >> 1);
      final int midMs = _replaySamples[mid].timestamp.millisecondsSinceEpoch;
      if (midMs <= targetMs) {
        result = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    return result;
  }

  void _applyReplaySampleToHistory(_LoggedSample sample) {
    for (final String channel in _channels) {
      final double? value = sample.values[channel];
      if (value == null) {
        continue;
      }
      _replayHistory[channel]!.add(
        FlSpot(sample.timestamp.millisecondsSinceEpoch.toDouble(), value),
      );
      _latestValues[channel] = value;
      _latestRawRmsVolts[channel] = value;
    }

    if (sample.sampleRateHz != null && sample.sampleRateHz! > 0) {
      _actualSampleRateHz = sample.sampleRateHz;
    }
    if (sample.samplesRead != null && sample.samplesRead! > 0) {
      _actualSamplesPerRead = sample.samplesRead;
    }
  }

  void _applyReplayCursor(int targetIndex) {
    if (targetIndex < _replayFrameIndex) {
      _clearReplayHistory();
      _replayFrameIndex = -1;
    }

    for (int index = _replayFrameIndex + 1; index <= targetIndex; index++) {
      _applyReplaySampleToHistory(_replaySamples[index]);
    }

    _replayFrameIndex = targetIndex;
  }

  void _setReplayPositionInternal(double positionMs) {
    final double totalDurationMs = _replayTotalDurationMs();
    final double clamped = positionMs.clamp(0.0, totalDurationMs).toDouble();
    final int targetIndex = _replayIndexForPositionMs(clamped);
    _applyReplayCursor(targetIndex);
    _replayPositionMs = clamped;
  }

  void _seekReplayTo(double positionMs) {
    if (_replaySamples.isEmpty) {
      return;
    }

    setState(() {
      _setReplayPositionInternal(positionMs);
      _replayPositionAtPlayStartMs = _replayPositionMs;
      _replayPlayStartedAt = DateTime.now();
    });
  }

  void _pauseReplay() {
    _stopReplayTimer();
    setState(() {
      _isReplayPlaying = false;
      _replayPositionAtPlayStartMs = _replayPositionMs;
      _replayPlayStartedAt = null;
    });
  }

  void _tickReplayPlayback() {
    if (!mounted || !_isReplayPlaying || _replaySamples.isEmpty) {
      return;
    }

    final DateTime startedAt = _replayPlayStartedAt ?? DateTime.now();
    final double elapsedMs =
        DateTime.now().difference(startedAt).inMilliseconds * _replaySpeed;
    final double nextPosition = min(
      _replayPositionAtPlayStartMs + elapsedMs,
      _replayTotalDurationMs(),
    );

    setState(() {
      _setReplayPositionInternal(nextPosition);
    });

    if (nextPosition >= _replayTotalDurationMs()) {
      _pauseReplay();
    }
  }

  void _startReplayPlayback() {
    if (_replaySamples.isEmpty) {
      return;
    }

    if (_replayPositionMs >= _replayTotalDurationMs()) {
      _seekReplayTo(0);
    }

    _stopReplayTimer();
    setState(() {
      _isReplayPlaying = true;
      _replayPositionAtPlayStartMs = _replayPositionMs;
      _replayPlayStartedAt = DateTime.now();
    });
    _replayTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _tickReplayPlayback(),
    );
  }

  void _toggleReplayPlayback() {
    if (_isReplayPlaying) {
      _pauseReplay();
      return;
    }
    _startReplayPlayback();
  }

  void _exitReplayMode() {
    _stopReplayTimer();
    setState(() {
      _isReplayMode = false;
      _isRunning = true;
      _acquisitionService.setRunning(true);
      _isReplayPlaying = false;
      _isLoadingReplayFile = false;
      _replaySamples.clear();
      _replayTimeIndex = <_BinaryTimeIndexEntry>[];
      _replayIndexStride = 1;
      _clearReplayHistory();
      _replayFrameIndex = -1;
      _replayPositionMs = 0;
      _replayPositionAtPlayStartMs = 0;
      _replayPlayStartedAt = null;
      _replayFilePath = null;
    });
  }

  Future<void> _pickReplayLogFile() async {
    if (_isLoadingReplayFile) {
      return;
    }

    setState(() {
      _isLoadingReplayFile = true;
      _replayLoadProgress = 0;
    });

    try {
      final Directory logDir = await _ensureDataLogDirectory();
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>[_binaryLogExtension],
        initialDirectory: logDir.path,
        withData: false,
      );
      if (result == null || result.files.single.path == null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isLoadingReplayFile = false;
          _replayLoadProgress = 0;
        });
        return;
      }

      final String path = result.files.single.path!;
      double lastUiProgress = -1;
      final _BinaryReplayLoadResult replayLoad =
          await _loadReplaySamplesFromBinary(
            File(path),
            onProgress: (double progress) {
              if (!mounted) {
                return;
              }
              final double clamped = progress.clamp(0.0, 1.0).toDouble();
              if (lastUiProgress >= 0 &&
                  (clamped - lastUiProgress).abs() < 0.01) {
                return;
              }
              lastUiProgress = clamped;
              setState(() {
                _replayLoadProgress = clamped;
              });
            },
          );
      final List<_LoggedSample> samples = replayLoad.samples;
      if (!mounted) {
        return;
      }
      if (samples.isEmpty) {
        setState(() {
          _isLoadingReplayFile = false;
          _replayLoadProgress = 0;
          _eventLogs.insert(
            0,
            '[${DateTime.now().toLocal()}] Replay load failed: no usable samples in ${_fileNameFromPath(path)}',
          );
          _trimLogs();
        });
        _showActionMessage('File log không có mẫu hợp lệ.');
        return;
      }

      _stopReplayTimer();
      setState(() {
        _isReplayMode = true;
        _isRunning = false;
        _acquisitionService.setRunning(false);
        _isReplayPlaying = false;
        _isLoadingReplayFile = false;
        _replayLoadProgress = 0;
        _replaySamples = samples;
        _replayTimeIndex = List<_BinaryTimeIndexEntry>.from(
          replayLoad.timeIndex,
          growable: false,
        );
        _replayIndexStride = max(1, replayLoad.indexStride);
        _clearReplayHistory();
        _replayFrameIndex = -1;
        _replayPositionMs = 0;
        _replayPositionAtPlayStartMs = 0;
        _replayPlayStartedAt = null;
        _replayFilePath = path;
        _eventLogs.insert(
          0,
          '[${DateTime.now().toLocal()}] Loaded replay log: ${_fileNameFromPath(path)} (${samples.length} samples, full payload)',
        );
        _trimLogs();
        _setReplayPositionInternal(0);
      });
      _showActionMessage('Đã nạp file log binary để phát lại.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      final String message = error is FormatException
          ? error.message
          : 'Định dạng file binary không đúng hoặc không thể đọc file.';
      setState(() {
        _isLoadingReplayFile = false;
        _replayLoadProgress = 0;
        _eventLogs.insert(
          0,
          '[${DateTime.now().toLocal()}] Replay load failed: $error',
        );
        _trimLogs();
      });
      _showActionMessage('Không thể nạp file log: $message');
    }
  }

  Future<void> _openDataLogFolder() async {
    try {
      final Directory logDir = await _ensureDataLogDirectory();
      if (Platform.isWindows) {
        await Process.start('explorer.exe', <String>[logDir.path]);
      } else if (Platform.isMacOS) {
        await Process.start('open', <String>[logDir.path]);
      } else if (Platform.isLinux) {
        await Process.start('xdg-open', <String>[logDir.path]);
      } else {
        _showActionMessage('Nền tảng hiện tại chưa hỗ trợ mở thư mục log.');
        return;
      }
      _showActionMessage('Đã mở thư mục log.');
    } catch (error) {
      _showActionMessage('Không thể mở thư mục log: $error');
    }
  }

  List<FlSpot> _activeCombinedHistory(String channel) {
    if (_isReplayMode) {
      return _replayHistory[channel] ?? const <FlSpot>[];
    }
    return _history[channel] ?? const <FlSpot>[];
  }

  String _formatDurationLabel(Duration duration) {
    final int totalSeconds = duration.inSeconds;
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _applyVoltageRange() {
    final double? minValue = double.tryParse(_voltageMinController.text.trim());
    final double? maxValue = double.tryParse(_voltageMaxController.text.trim());

    if (minValue == null || maxValue == null || minValue >= maxValue) {
      setState(() {
        _eventLogs.insert(
          0,
          '[${DateTime.now().toLocal()}] Invalid voltage range. Use min < max.',
        );
        _trimLogs();
      });
      return;
    }

    setState(() {
      _voltageMin = minValue;
      _voltageMax = maxValue;
      _bridgeArguments = _upsertBridgeFlag(
        _bridgeArguments,
        '--min',
        minValue.toString(),
      );
      _bridgeArguments = _upsertBridgeFlag(
        _bridgeArguments,
        '--max',
        maxValue.toString(),
      );
      _bridgeArgsController.text = _bridgeArguments;
      _eventLogs.insert(
        0,
        '[${DateTime.now().toLocal()}] Input range updated to ${minValue.toStringAsFixed(2)} ${_bridgeRawUnitLabel()} .. ${maxValue.toStringAsFixed(2)} ${_bridgeRawUnitLabel()}',
      );
      _trimLogs();
    });
    unawaited(_saveSettings());
  }

  void _applySamplingSettings() {
    final int? rate = int.tryParse(_sampleRateController.text.trim());
    final int? samples = int.tryParse(_samplesPerReadController.text.trim());

    if (rate == null || samples == null || rate <= 0 || samples <= 0) {
      setState(() {
        _eventLogs.insert(
          0,
          '[${DateTime.now().toLocal()}] Invalid sampling settings. Use positive integers.',
        );
        _trimLogs();
      });
      return;
    }

    setState(() {
      _sampleRateHz = rate;
      _samplesPerRead = samples;
      _bridgeArguments = _upsertBridgeFlag(
        _bridgeArguments,
        '--rate',
        _sampleRateHz.toString(),
      );
      _bridgeArguments = _upsertBridgeFlag(
        _bridgeArguments,
        '--samples',
        _samplesPerRead.toString(),
      );
      _bridgeArgsController.text = _bridgeArguments;
      _eventLogs.insert(
        0,
        '[${DateTime.now().toLocal()}] Sampling updated: rate=$_sampleRateHz Hz, samples/read=$_samplesPerRead',
      );
      _trimLogs();
    });

    _acquisitionService.setMockSamplingConfig(
      sampleRateHz: _sampleRateHz,
      samplesPerRead: _samplesPerRead,
    );
    if (!_useBridge) {
      _startAcquisition();
    }

    unawaited(_saveSettings());
  }

  void _applyChartScale() {
    final double? minG = double.tryParse(_chartMinController.text.trim());
    final double? maxG = double.tryParse(_chartMaxController.text.trim());

    if (minG == null || maxG == null || minG >= maxG) {
      setState(() {
        _eventLogs.insert(
          0,
          '[${DateTime.now().toLocal()}] Invalid chart scale. Use min < max.',
        );
        _trimLogs();
      });
      return;
    }

    setState(() {
      _chartMinG = minG;
      _chartMaxG = maxG;

      _warningThreshold = _warningThreshold.clamp(_chartMinG, _chartMaxG);
      _dangerThreshold = _dangerThreshold.clamp(_chartMinG, _chartMaxG);
      if (_warningThreshold >= _dangerThreshold) {
        final double range = _chartMaxG - _chartMinG;
        _warningThreshold = _chartMinG + range * 0.6;
        _dangerThreshold = _chartMinG + range * 0.8;
      }

      _eventLogs.insert(
        0,
        '[${DateTime.now().toLocal()}] Chart scale updated to ${_chartMinG.toStringAsFixed(2)} .. ${_chartMaxG.toStringAsFixed(2)} g',
      );
      _trimLogs();
    });

    unawaited(_saveSettings());
  }

  void _applyWaveformScaleRange() {
    final double? minMs = double.tryParse(
      _waveformTimeWindowMinController.text.trim(),
    );
    final double? maxMs = double.tryParse(
      _waveformTimeWindowMaxController.text.trim(),
    );

    if (minMs == null || maxMs == null || minMs <= 0 || minMs >= maxMs) {
      setState(() {
        _eventLogs.insert(
          0,
          '[${DateTime.now().toLocal()}] Invalid waveform time scale range. Use 0 < min < max (ms).',
        );
        _trimLogs();
      });
      return;
    }

    setState(() {
      _waveformTimeWindowMinMs = minMs;
      _waveformTimeWindowMaxMs = maxMs;
      _waveformTimeWindowMs = _clampWaveformTimeWindowMs(_waveformTimeWindowMs);
      _waveformTimeWindowController.text = _waveformTimeWindowMs.toString();
      _eventLogs.insert(
        0,
        '[${DateTime.now().toLocal()}] Waveform time scale range updated to ${_waveformTimeWindowMinMs.toStringAsFixed(1)} .. ${_waveformTimeWindowMaxMs.toStringAsFixed(1)} ms',
      );
      _trimLogs();
    });

    unawaited(_saveSettings());
  }

  void _startAcquisition() {
    _acquisitionService.setMockSamplingConfig(
      sampleRateHz: _sampleRateHz,
      samplesPerRead: _samplesPerRead,
    );
    final int intervalMs = max(
      20,
      ((_samplesPerRead * 1000) / _sampleRateHz).round(),
    );
    _sampleIntervalMs = intervalMs;
    _acquisitionService.startMock(intervalMs: intervalMs);
  }

  void _toggleRun() {
    setState(() {
      _isRunning = !_isRunning;
      _acquisitionService.setRunning(_isRunning);
      _eventLogs.insert(
        0,
        '[${DateTime.now().toLocal()}] Thu nhận ${_isRunning ? 'bắt đầu' : 'tạm dừng'}',
      );
    });
  }

  void _showActionMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirmDisconnectConnection() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Ngắt kết nối nguồn dữ liệu?'),
          content: Text(
            _useBridge
                ? 'Dừng tiến trình bridge NI-DAQmx và ngắt kết nối ngay bây giờ?'
                : 'Ngắt kết nối demo ngay bây giờ?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Ngắt kết nối'),
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }

  Future<void> _connectConnection({
    String trigger = 'thao tác người dùng',
  }) async {
    if (!_useBridge) {
      setState(() {
        _isConnected = true;
        _actualSampleRateHz = null;
        _actualSamplesPerRead = null;
        _acquisitionService.setMockConnected(true);
        _eventLogs.insert(
          0,
          '[${DateTime.now().toLocal()}] Đã kết nối demo ($trigger)',
        );
        _trimLogs();
      });
      _showActionMessage('Đã kết nối demo.');
      return;
    }

    if (_acquisitionService.isBridgeRunning) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isConnected = true;
      });
      return;
    }

    try {
      if (!Platform.isWindows && _bridgeExecutablePath.trim().isEmpty) {
        setState(() {
          _eventLogs.insert(
            0,
            '[${DateTime.now().toLocal()}] Đường dẫn bridge trống. Hãy giữ chế độ demo hoặc đặt đường dẫn hợp lệ.',
          );
          _isConnected = false;
          _trimLogs();
        });
        _showActionMessage('Đường dẫn bridge đang trống.');
        return;
      }

      await _acquisitionService.startBridge(
        executablePath: _bridgeExecutablePath,
        args: _splitArguments(
          _aiChannelMode == BridgeAiChannelMode.accel
              ? _upsertBridgeFlag(
                  _upsertBridgeFlag(
                    _bridgeArguments,
                    '--ai-mode',
                    _aiModeFlagValue(_aiChannelMode),
                  ),
                  '--accel-sens',
                  _effectiveAccelSensitivityMvPerG().toString(),
                )
              : _upsertBridgeFlag(
                  _bridgeArguments,
                  '--ai-mode',
                  _aiModeFlagValue(_aiChannelMode),
                ),
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isConnected = _acquisitionService.isBridgeRunning;
        _eventLogs.insert(
          0,
          '[${DateTime.now().toLocal()}] Đã kết nối bridge ($trigger)',
        );
        _trimLogs();
      });
      _showActionMessage('Đã kết nối bridge.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isConnected = false;
        _actualSampleRateHz = null;
        _actualSamplesPerRead = null;
        _eventLogs.insert(
          0,
          '[${DateTime.now().toLocal()}] Kết nối bridge thất bại: $error',
        );
        _trimLogs();
      });
      _showActionMessage('Kết nối bridge thất bại.');
    }
  }

  Future<void> _disconnectConnection({
    String reason = 'thao tác người dùng',
  }) async {
    if (!_useBridge) {
      setState(() {
        _isConnected = false;
        _actualSampleRateHz = null;
        _actualSamplesPerRead = null;
        _acquisitionService.setMockConnected(false);
        _eventLogs.insert(
          0,
          '[${DateTime.now().toLocal()}] Đã ngắt kết nối demo ($reason)',
        );
        _trimLogs();
      });
      _showActionMessage('Đã ngắt kết nối demo. Lý do: $reason');
      return;
    }

    if (!_acquisitionService.isBridgeRunning) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isConnected = false;
        _actualSampleRateHz = null;
        _actualSamplesPerRead = null;
        _eventLogs.insert(
          0,
          '[${DateTime.now().toLocal()}] Bridge đã ngắt trước đó ($reason)',
        );
        _trimLogs();
      });
      _showActionMessage('Bridge đã ngắt trước đó.');
      return;
    }

    await _acquisitionService.stopBridge();
    if (!mounted) {
      return;
    }
    setState(() {
      _isConnected = false;
      _actualSampleRateHz = null;
      _actualSamplesPerRead = null;
      _eventLogs.insert(
        0,
        '[${DateTime.now().toLocal()}] Đã ngắt kết nối bridge ($reason)',
      );
      _trimLogs();
    });
    _showActionMessage('Đã ngắt kết nối bridge. Lý do: $reason');
  }

  Future<void> _toggleConnection() async {
    if (_isConnected) {
      final bool shouldDisconnect = await _confirmDisconnectConnection();
      if (!shouldDisconnect) {
        _showActionMessage('Đã hủy thao tác ngắt kết nối.');
        return;
      }
      await _disconnectConnection(
        reason: 'chuyển trạng thái trên thanh công cụ',
      );
      return;
    }
    await _connectConnection(trigger: 'chuyển trạng thái trên thanh công cụ');
  }

  List<String> _splitArguments(String raw) {
    return raw
        .trim()
        .split(RegExp(r'\s+'))
        .where((String token) => token.isNotEmpty)
        .toList();
  }

  Future<void> _toggleDataSource(bool enabled) async {
    if (enabled == _useBridge) {
      return;
    }

    if (!enabled && _acquisitionService.isBridgeRunning) {
      await _disconnectConnection(reason: 'chuyển sang nguồn demo');
    }

    if (!mounted) {
      return;
    }

    if (!enabled) {
      _acquisitionService.setMockConnected(true);
    }

    _acquisitionService.setSource(
      enabled ? AcquisitionSource.bridge : AcquisitionSource.mock,
    );

    setState(() {
      _useBridge = enabled;
      _isConnected = enabled ? _acquisitionService.isBridgeRunning : true;
      _eventLogs.insert(
        0,
        '[${DateTime.now().toLocal()}] Nguồn dữ liệu: ${enabled ? 'NI-DAQmx bridge (đa kênh)' : 'Demo'}',
      );
    });
    unawaited(_saveSettings());

    if (enabled) {
      await _connectConnection(trigger: 'chuyển sang nguồn bridge');
    }
  }

  void _onAcquisitionSample(AcquisitionSample sample) {
    if (!_isRunning || !mounted || _isReplayMode) {
      return;
    }

    setState(() {
      final DaqFftFrame? fftFrame = sample.fftFrame;
      if (fftFrame != null) {
        _bridgeFftSampleRateHz = fftFrame.sampleRateHz;
        _bridgeFftBinCount = fftFrame.binCount;
        _bridgeFftSamplesRead = fftFrame.samplesRead;
        _bridgeFftCapturedAt = DateTime.now();
        for (
          int ch = 0;
          ch < fftFrame.channelCount && ch < _channels.length;
          ch++
        ) {
          _bridgeFftMags[_channels[ch]] = fftFrame.channelMags(ch);
        }
      }

      final DaqWaveFrame? waveFrame = sample.waveFrame;
      if (waveFrame != null) {
        _bridgeWaveSampleRateHz = waveFrame.sampleRateHz;
        _bridgeWaveDecimStep = waveFrame.decimStep;
        _bridgeWaveCapturedAt = DateTime.now();
        for (
          int ch = 0;
          ch < waveFrame.channelCount && ch < _channels.length;
          ch++
        ) {
          _bridgeWaveSamples[_channels[ch]] = waveFrame.channelSamples[ch];
        }
      }

      for (final MapEntry<String, double> entry in sample.values.entries) {
        _appendChannelValue(entry.key, entry.value);
      }

      for (final MapEntry<String, double> entry in sample.rawRmsVolts.entries) {
        _latestRawRmsVolts[entry.key] = entry.value;
      }

      if (sample.sampleRateHz != null && sample.sampleRateHz! > 0) {
        _actualSampleRateHz = sample.sampleRateHz;
      }
      if (sample.samplesRead != null && sample.samplesRead! > 0) {
        _actualSamplesPerRead = sample.samplesRead;
      }

      _appendDataLog(sample);

      _isConnected = _useBridge
          ? _acquisitionService.isBridgeRunning
          : _acquisitionService.isMockConnected;
      _trimLogs();
    });
  }

  void _appendChannelValue(String channel, double value) {
    _latestValues[channel] = value;
    final SensorState currentState = _toState(value);
    final SensorState previous = _lastStates[channel] ?? SensorState.normal;
    if (currentState != previous && currentState != SensorState.normal) {
      _eventLogs.insert(
        0,
        '[${DateTime.now().toLocal()}] $channel switched to ${_stateLabel(currentState).toUpperCase()} (${value.toStringAsFixed(3)} g)',
      );
    }
    _lastStates[channel] = currentState;

    final List<FlSpot> points = _history[channel]!;
    final double nowMs = DateTime.now().millisecondsSinceEpoch.toDouble();
    points.add(FlSpot(nowMs, value));

    final double minMsToKeep = DateTime.now()
        .subtract(_historyRetention)
        .millisecondsSinceEpoch
        .toDouble();
    while (points.isNotEmpty && points.first.x < minMsToKeep) {
      points.removeAt(0);
    }
  }

  List<FlSpot> _visibleSpotsForCombinedChart(
    String channel,
    int selectedWindowMinutes,
    double frameNowMs,
  ) {
    final List<FlSpot> source = _activeCombinedHistory(channel);
    if (source.isEmpty) {
      final double nowSec = frameNowMs / 1000.0;
      return <FlSpot>[
        FlSpot(nowSec - 1, _chartMinG),
        FlSpot(nowSec, _chartMinG),
      ];
    }

    final DateTime now = DateTime.fromMillisecondsSinceEpoch(
      frameNowMs.toInt(),
    );
    List<FlSpot> visible = source;
    double? cutoffMs;

    if (selectedWindowMinutes == -1) {
      final double realtimeCutoffMs = now
          .subtract(Duration(seconds: _combinedRealtimeSeconds))
          .millisecondsSinceEpoch
          .toDouble();
      cutoffMs = realtimeCutoffMs;
      visible = source
          .where((FlSpot spot) => spot.x >= realtimeCutoffMs)
          .toList();
      if (visible.isEmpty) {
        visible = <FlSpot>[FlSpot(realtimeCutoffMs, source.last.y)];
      }
    } else if (selectedWindowMinutes > 0) {
      final double windowCutoffMs = now
          .subtract(Duration(minutes: selectedWindowMinutes))
          .millisecondsSinceEpoch
          .toDouble();
      cutoffMs = windowCutoffMs;
      visible = source
          .where((FlSpot spot) => spot.x >= windowCutoffMs)
          .toList();
      if (visible.isEmpty) {
        visible = <FlSpot>[FlSpot(windowCutoffMs, source.last.y)];
      }
    }

    if (cutoffMs != null) {
      final FlSpot firstVisible = visible.first;
      if (firstVisible.x > cutoffMs) {
        double anchorY = firstVisible.y;
        for (int i = source.length - 1; i >= 0; i--) {
          if (source[i].x <= cutoffMs) {
            anchorY = source[i].y;
            break;
          }
        }
        visible = <FlSpot>[FlSpot(cutoffMs, anchorY), ...visible];
      }
    }

    final List<FlSpot> absolute = visible
        .map((FlSpot spot) => FlSpot(spot.x / 1000, _clampYForChart(spot.y)))
        .toList();

    if (absolute.length == 1) {
      final FlSpot only = absolute.first;
      return <FlSpot>[only, FlSpot(only.x + 1, only.y)];
    }

    return absolute;
  }

  double? _combinedFixedWindowSeconds() {
    if (_selectedCombinedWindowMinutes == -1) {
      return _combinedRealtimeSeconds.toDouble();
    }
    if (_selectedCombinedWindowMinutes > 0) {
      return (_selectedCombinedWindowMinutes * 60).toDouble();
    }
    return null;
  }

  double _channelsFixedWindowSeconds() {
    return _combinedFixedWindowSeconds() ??
        _historyRetention.inSeconds.toDouble();
  }

  List<FlSpot> _visibleSpotsForChannelChart(String channel, double frameNowMs) {
    final List<FlSpot> source = _history[channel]!;
    if (source.isEmpty) {
      return <FlSpot>[FlSpot(0, _chartMinG), FlSpot(1, _chartMinG)];
    }

    final double windowSeconds = _channelsFixedWindowSeconds();
    final double cutoffMs = frameNowMs - (windowSeconds * 1000);
    List<FlSpot> visible = source
        .where((FlSpot spot) => spot.x >= cutoffMs)
        .toList();

    if (visible.isEmpty) {
      visible = <FlSpot>[FlSpot(cutoffMs, source.last.y)];
    }

    final double baseMs = visible.first.x;
    final List<FlSpot> rebased = visible
        .map(
          (FlSpot spot) =>
              FlSpot((spot.x - baseMs) / 1000, _clampYForChart(spot.y)),
        )
        .toList();

    if (rebased.length == 1) {
      final FlSpot only = rebased.first;
      return <FlSpot>[only, FlSpot(only.x + 1, only.y)];
    }

    return rebased;
  }

  double _clampYForChart(double value) {
    if (_chartMaxG <= _chartMinG) {
      return value;
    }

    const double epsilon = 0.001;
    final double minSafe = _chartMinG + epsilon;
    final double maxSafe = _chartMaxG - epsilon;
    if (maxSafe <= minSafe) {
      return value.clamp(_chartMinG, _chartMaxG).toDouble();
    }

    return value.clamp(minSafe, maxSafe).toDouble();
  }

  double _combinedXAxisIntervalSeconds(double visibleSpanSeconds) {
    switch (_selectedCombinedWindowMinutes) {
      case -1:
        return 10;
      case 15:
        return 5 * 60;
      case 30:
        return 10 * 60;
      case 60:
        return 15 * 60;
      case 120:
        return 30 * 60;
      case 240:
        return 60 * 60;
      case 0:
        return max(visibleSpanSeconds / 5, 1);
      default:
        return max(visibleSpanSeconds / 4, 1);
    }
  }

  String _formatSystemTimeLabel(double secondsSinceEpoch) {
    final DateTime time = DateTime.fromMillisecondsSinceEpoch(
      (secondsSinceEpoch * 1000).round(),
    ).toLocal();
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  Widget _buildCombinedBottomTitle(double value, TitleMeta meta) {
    const TextStyle style = TextStyle(
      fontSize: 10,
      color: Color(0xFF5E6A79),
      fontWeight: FontWeight.w600,
    );

    final bool isStart = (value - meta.min).abs() < 0.5;
    final bool isEnd = (value - meta.max).abs() < 0.5;
    if (isStart || isEnd) {
      return const SizedBox.shrink();
    }

    final String label = _formatSystemTimeLabel(value);

    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 6,
      child: Text(label, style: style),
    );
  }

  void _trimLogs() {
    if (_eventLogs.length > 80) {
      _eventLogs.removeRange(80, _eventLogs.length);
    }
  }

  Future<void> _toggleDataLogging() async {
    setState(() {
      _dataLoggingEnabled = !_dataLoggingEnabled;
      _eventLogs.insert(
        0,
        '[${DateTime.now().toLocal()}] Data logging ${_dataLoggingEnabled ? 'enabled' : 'disabled'}',
      );
      _trimLogs();
    });

    if (_dataLoggingEnabled) {
      await _startDataLoggingSession();
    } else {
      await _finalizeDataLoggingSession();
    }

    _syncDataLoggingBlinkTimer();
    unawaited(_saveSettings());
  }

  void _syncDataLoggingBlinkTimer() {
    if (!_dataLoggingEnabled) {
      _dataLoggingBlinkTimer?.cancel();
      _dataLoggingBlinkTimer = null;
      if (mounted && _dataLoggingBlinkOn) {
        setState(() {
          _dataLoggingBlinkOn = false;
        });
      } else {
        _dataLoggingBlinkOn = false;
      }
      return;
    }

    _dataLoggingBlinkOn = true;
    _dataLoggingBlinkTimer ??= Timer.periodic(
      const Duration(milliseconds: 450),
      (_) {
        if (!mounted || !_dataLoggingEnabled) {
          return;
        }
        setState(() {
          _dataLoggingBlinkOn = !_dataLoggingBlinkOn;
        });
      },
    );
  }

  SensorState _toState(double value) {
    if (value >= _dangerThreshold) {
      return SensorState.danger;
    }
    if (value >= _warningThreshold) {
      return SensorState.warning;
    }
    return SensorState.normal;
  }

  String _stateLabel(SensorState state) {
    switch (state) {
      case SensorState.normal:
        return 'Bình thường';
      case SensorState.warning:
        return 'Trung bình';
      case SensorState.danger:
        return 'Cao';
    }
  }

  Color _stateColor(SensorState state) {
    switch (state) {
      case SensorState.normal:
        return const Color(0xFF2E8B57);
      case SensorState.warning:
        return const Color(0xFFE4A100);
      case SensorState.danger:
        return const Color(0xFFC0392B);
    }
  }

  Color _channelColor(String channel) {
    final int index = _channels.indexOf(channel);
    if (index < 0) {
      return const Color(0xFF005A9C);
    }
    return _channelPalette[index % _channelPalette.length];
  }

  bool _isCombinedChannelVisible(String channel) {
    return !_hiddenCombinedChannels.contains(channel);
  }

  bool _isChannelVisible(String channel) {
    return !_hiddenChannels.contains(channel);
  }

  @override
  Widget build(BuildContext context) {
    final String screenTitle = switch (_selectedScreenIndex) {
      0 => 'Kênh tổng hợp',
      1 => 'Kênh cảm biến',
      2 => 'Log data',
      _ => 'Cài đặt',
    };
    final ButtonStyle topActionButtonStyle = FilledButton.styleFrom(
      visualDensity: const VisualDensity(horizontal: -2, vertical: -1),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      textStyle: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
    );
    final ButtonStyle sourceButtonStyle = _useBridge
        ? topActionButtonStyle
        : topActionButtonStyle.copyWith(
            backgroundColor: const WidgetStatePropertyAll(Color(0xFFC0392B)),
            foregroundColor: const WidgetStatePropertyAll(Colors.white),
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(screenTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: <Widget>[
                FilledButton.tonalIcon(
                  style: topActionButtonStyle,
                  onPressed: _toggleDataLogging,
                  icon: Icon(
                    Icons.fiber_manual_record,
                    color: _dataLoggingEnabled
                        ? (_dataLoggingBlinkOn
                              ? const Color(0xFFC0392B)
                              : const Color(0x44C0392B))
                        : const Color(0xFF5E6A79),
                  ),
                  label: Text(
                    _dataLoggingEnabled ? 'Tạm dừng ghi' : 'Bắt đầu ghi',
                    softWrap: false,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  style: topActionButtonStyle,
                  onPressed: _toggleRun,
                  icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                  label: Text(
                    _isRunning ? 'Đang chạy' : 'Tạm dừng',
                    softWrap: false,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  style: sourceButtonStyle,
                  onPressed: () {
                    unawaited(_toggleDataSource(!_useBridge));
                  },
                  icon: const Icon(Icons.swap_horiz),
                  label: Text(
                    _useBridge ? 'Nguồn bridge' : 'Nguồn demo',
                    softWrap: false,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  style: topActionButtonStyle,
                  onPressed: _toggleConnection,
                  icon: Icon(_isConnected ? Icons.link : Icons.link_off),
                  label: Text(
                    _useBridge
                        ? (_isConnected
                              ? 'Bridge đã kết nối'
                              : 'Bridge đã ngắt')
                        : (_isConnected ? 'Demo đã kết nối' : 'Demo đã ngắt'),
                    softWrap: false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (_selectedScreenIndex == 0) {
            return _buildCombinedChartScreen(constraints);
          }

          if (_selectedScreenIndex == 1) {
            return _buildMonitoringScreen(constraints);
          }

          if (_selectedScreenIndex == 2) {
            return _buildPanelsScreen(constraints);
          }

          return _buildSettingsScreen();
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedScreenIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedScreenIndex = index;
          });
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.multiline_chart),
            label: 'Tổng hợp',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart),
            label: 'Kênh cảm biến',
          ),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Log data'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Cài đặt'),
        ],
      ),
    );
  }

  Widget _buildMonitoringScreen(BoxConstraints constraints) {
    final double frameNowMs = DateTime.now().millisecondsSinceEpoch.toDouble();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: <Widget>[
          _buildSamplingInfoCard(),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        'Hiển thị ${_channels.where(_isChannelVisible).length}/${_channels.length} kênh',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF5E6A79),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _hiddenChannels.clear();
                          });
                        },
                        child: const Text('Hiện tất cả'),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _hiddenChannels
                              ..clear()
                              ..addAll(_channels);
                          });
                        },
                        child: const Text('Bỏ tất cả'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _channels.map((String channel) {
                      final Color color = _channelColor(channel);
                      final bool selected = _isChannelVisible(channel);
                      return FilterChip(
                        selected: selected,
                        onSelected: (bool isSelected) {
                          setState(() {
                            if (isSelected) {
                              _hiddenChannels.remove(channel);
                            } else {
                              _hiddenChannels.add(channel);
                            }
                          });
                        },
                        avatar: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        label: Text(
                          channel,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(child: _buildSensorGrid(frameNowMs)),
        ],
      ),
    );
  }

  Widget _buildPanelsScreen(BoxConstraints constraints) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: <Widget>[
          _buildSamplingInfoCard(),
          const SizedBox(height: 10),
          Expanded(child: _buildEventPanel()),
        ],
      ),
    );
  }

  /// Simple Cooley-Tukey FFT on [input] (length must be power-of-2).
  /// Returns list of magnitude values (0..N/2).
  List<double> _fft(List<double> input) {
    final int n = input.length;
    if (n == 0) return <double>[];

    // Bit-reversal permutation
    final List<double> re = List<double>.from(input);
    final List<double> im = List<double>.filled(n, 0.0);

    int j = 0;
    for (int i = 1; i < n; i++) {
      int bit = n >> 1;
      while ((j & bit) != 0) {
        j ^= bit;
        bit >>= 1;
      }
      j ^= bit;
      if (i < j) {
        final double tmpR = re[i];
        re[i] = re[j];
        re[j] = tmpR;
        final double tmpI = im[i];
        im[i] = im[j];
        im[j] = tmpI;
      }
    }

    // Cooley-Tukey iterative FFT
    for (int len = 2; len <= n; len <<= 1) {
      final double ang = -2 * pi / len;
      final double wRe = cos(ang);
      final double wIm = sin(ang);
      for (int i = 0; i < n; i += len) {
        double curRe = 1.0;
        double curIm = 0.0;
        for (int k = 0; k < len ~/ 2; k++) {
          final double uRe = re[i + k];
          final double uIm = im[i + k];
          final double vRe =
              re[i + k + len ~/ 2] * curRe - im[i + k + len ~/ 2] * curIm;
          final double vIm =
              re[i + k + len ~/ 2] * curIm + im[i + k + len ~/ 2] * curRe;
          re[i + k] = uRe + vRe;
          im[i + k] = uIm + vIm;
          re[i + k + len ~/ 2] = uRe - vRe;
          im[i + k + len ~/ 2] = uIm - vIm;
          final double nextRe = curRe * wRe - curIm * wIm;
          curIm = curRe * wIm + curIm * wRe;
          curRe = nextRe;
        }
      }
    }

    final int half = n ~/ 2;
    final List<double> magnitudes = List<double>.filled(half, 0.0);
    for (int k = 0; k < half; k++) {
      magnitudes[k] = sqrt(re[k] * re[k] + im[k] * im[k]) / half;
    }
    return magnitudes;
  }

  /// Compute FFT for [channel] using the last [windowSize] history samples.
  /// DC is removed (mean subtracted), Hann window applied.
  /// Returns (freqs, mags) starting from bin 1 (skipping DC), or empty if not enough data.
  ({
    List<double> freqs,
    List<double> mags,
    double sampleRateHz,
    int samplesUsed,
  })
  _computeChannelFft(String channel, int windowSize) {
    final List<FlSpot> pts = _activeCombinedHistory(channel);
    if (pts.length < 8) {
      return (
        freqs: <double>[],
        mags: <double>[],
        sampleRateHz: 0,
        samplesUsed: 0,
      );
    }

    final int available = pts.length;
    final int n = available >= windowSize ? windowSize : _prevPow2(available);
    final List<FlSpot> window = pts.sublist(pts.length - n);

    // Compute effective sample rate from timestamps (ms)
    double totalDurationMs = window.last.x - window.first.x;
    if (totalDurationMs <= 0) totalDurationMs = (n - 1) * 100.0;
    final double effectiveSrHz = (n - 1) * 1000.0 / totalDurationMs;

    // Subtract mean (DC removal) then apply Hann window
    final double mean = window.fold(0.0, (double s, FlSpot sp) => s + sp.y) / n;
    final List<double> samples = List<double>.generate(n, (int i) {
      final double hann = 0.5 * (1.0 - cos(2.0 * pi * i / (n - 1)));
      return (window[i].y - mean) * hann;
    });

    final List<double> allMags = _fft(samples);

    // Skip bin 0 (DC remainder) – start from bin 1
    final int half = allMags.length;
    if (half < 2) {
      return (
        freqs: <double>[],
        mags: <double>[],
        sampleRateHz: effectiveSrHz,
        samplesUsed: n,
      );
    }
    final List<double> mags = allMags.sublist(1);
    final List<double> freqs = List<double>.generate(
      mags.length,
      (int k) => (k + 1) * effectiveSrHz / n,
    );

    return (
      freqs: freqs,
      mags: mags,
      sampleRateHz: effectiveSrHz,
      samplesUsed: n,
    );
  }

  int _prevPow2(int n) {
    int p = 1;
    while (p * 2 <= n) {
      p *= 2;
    }
    return p;
  }

  _LoggedSample? _currentReplaySample() {
    if (!_isReplayMode ||
        _replayFrameIndex < 0 ||
        _replayFrameIndex >= _replaySamples.length) {
      return null;
    }
    return _replaySamples[_replayFrameIndex];
  }

  String? _resolvePayloadText({String? text, Uint8List? bytes}) {
    final String? direct = text?.trim();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    return _decodePayloadBytes(bytes);
  }

  Map<String, dynamic>? _decodePayloadObject(String? raw) {
    if (raw == null) {
      return null;
    }
    final String text = raw.trim();
    if (text.isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  ({
    int sampleRateHz,
    int decimStep,
    String unit,
    Map<String, List<double>> channelSamples,
  })?
  _extractReplayWavePayload(_LoggedSample sample) {
    final Map<String, dynamic>? payload = _decodePayloadObject(
      _resolvePayloadText(
        text: sample.wavePayloadJson,
        bytes: sample.wavePayloadBytes,
      ),
    );
    if (payload == null) {
      return null;
    }

    final int? sampleRateHz = (payload['sampleRateHz'] as num?)?.toInt();
    final int decimStep = ((payload['decimStep'] as num?)?.toInt() ?? 1).clamp(
      1,
      1 << 20,
    );
    final String unit = payload['unit']?.toString() ?? 'g';
    if (sampleRateHz == null || sampleRateHz <= 0) {
      return null;
    }

    final Map<String, List<double>> channelSamples = <String, List<double>>{};
    final Object? channelsRaw = payload['channels'];
    if (channelsRaw is Map) {
      for (final MapEntry<dynamic, dynamic> entry in channelsRaw.entries) {
        final String channel = entry.key.toString();
        final Object? samplesRaw = entry.value;
        if (samplesRaw is! List) {
          continue;
        }
        final List<double> samples = samplesRaw
            .whereType<num>()
            .map((num value) => value.toDouble())
            .toList(growable: false);
        if (samples.isNotEmpty) {
          channelSamples[channel] = samples;
        }
      }
    }

    // Backward compatibility for older single-channel payload format.
    if (channelSamples.isEmpty) {
      final String channel = payload['channel']?.toString() ?? '';
      final Object? samplesRaw = payload['samples'];
      if (channel.isNotEmpty && samplesRaw is List) {
        final List<double> samples = samplesRaw
            .whereType<num>()
            .map((num value) => value.toDouble())
            .toList(growable: false);
        if (samples.isNotEmpty) {
          channelSamples[channel] = samples;
        }
      }
    }

    if (channelSamples.isEmpty) {
      return null;
    }
    return (
      sampleRateHz: sampleRateHz,
      decimStep: decimStep,
      unit: unit,
      channelSamples: channelSamples,
    );
  }

  ({
    int sampleRateHz,
    int samplesRead,
    int binCount,
    Map<String, List<double>> channelMags,
  })?
  _extractReplayFftPayload(_LoggedSample sample) {
    final Map<String, dynamic>? payload = _decodePayloadObject(
      _resolvePayloadText(
        text: sample.fftPayloadJson,
        bytes: sample.fftPayloadBytes,
      ),
    );
    if (payload == null) {
      return null;
    }

    final int? sampleRateHz = (payload['sampleRateHz'] as num?)?.toInt();
    final int samplesRead = (payload['samplesRead'] as num?)?.toInt() ?? 0;
    final int binCount = (payload['binCount'] as num?)?.toInt() ?? 0;
    if (sampleRateHz == null || sampleRateHz <= 0) {
      return null;
    }

    final Map<String, List<double>> channelMags = <String, List<double>>{};
    final Object? channelsRaw = payload['channels'];
    if (channelsRaw is Map) {
      for (final MapEntry<dynamic, dynamic> entry in channelsRaw.entries) {
        final String channel = entry.key.toString();
        final Object? magsRaw = entry.value;
        if (magsRaw is! List) {
          continue;
        }
        final List<double> mags = magsRaw
            .whereType<num>()
            .map((num value) => value.toDouble())
            .toList(growable: false);
        if (mags.isNotEmpty) {
          channelMags[channel] = mags;
        }
      }
    }

    // Backward compatibility for older single-channel payload format.
    if (channelMags.isEmpty) {
      final String channel = payload['channel']?.toString() ?? '';
      final Object? magsRaw = payload['mags'];
      if (channel.isNotEmpty && magsRaw is List) {
        final List<double> mags = magsRaw
            .whereType<num>()
            .map((num value) => value.toDouble())
            .toList(growable: false);
        if (mags.isNotEmpty) {
          channelMags[channel] = mags;
        }
      }
    }

    if (channelMags.isEmpty) {
      return null;
    }
    return (
      sampleRateHz: sampleRateHz,
      samplesRead: samplesRead,
      binCount: binCount,
      channelMags: channelMags,
    );
  }

  static const double _fftDisplayMinHz = 10.0;
  static const double _fftDisplayMaxHz = 5000.0;
  static const double _fftDisplayMinX = 1.0;
  static const double _fftDisplayMaxX = 3.7;

  double _fftAxisXForFrequency(double frequencyHz) {
    final double clampedFrequency = frequencyHz.clamp(
      _fftDisplayMinHz,
      _fftDisplayMaxHz,
    );
    final double minLog = log(_fftDisplayMinHz);
    final double maxLog = log(_fftDisplayMaxHz);
    final double normalized =
        (log(clampedFrequency) - minLog) / (maxLog - minLog);
    return _fftDisplayMinX + normalized * (_fftDisplayMaxX - _fftDisplayMinX);
  }

  double _fftFrequencyForAxisX(double axisX) {
    final double normalized =
        ((axisX - _fftDisplayMinX) / (_fftDisplayMaxX - _fftDisplayMinX)).clamp(
          0.0,
          1.0,
        );
    final double minLog = log(_fftDisplayMinHz);
    final double maxLog = log(_fftDisplayMaxHz);
    return exp(minLog + normalized * (maxLog - minLog));
  }

  bool _isCloseTo(double value, double target, [double epsilon = 0.05]) {
    return (value - target).abs() <= epsilon;
  }

  String _fftAxisLabelForValue(double value) {
    if (_isCloseTo(value, _fftAxisXForFrequency(10))) return '10';
    if (_isCloseTo(value, _fftAxisXForFrequency(100))) return '100';
    if (_isCloseTo(value, _fftAxisXForFrequency(1000))) return '1000';
    if (_isCloseTo(value, _fftAxisXForFrequency(5000))) return '5000';
    return '';
  }

  List<FlSpot> _buildFftPlotSpots(List<double> freqs, List<double> mags) {
    final List<FlSpot> spots = <FlSpot>[];
    final int count = min(freqs.length, mags.length);
    for (int i = 0; i < count; i++) {
      final double frequencyHz = freqs[i];
      if (frequencyHz < _fftDisplayMinHz) {
        continue;
      }
      final double axisX = _fftAxisXForFrequency(frequencyHz);
      spots.add(FlSpot(axisX, mags[i]));
    }
    return spots;
  }

  Widget _buildFftPanel({bool compact = false}) {
    final _LoggedSample? replaySample = _currentReplaySample();
    final ({
      int sampleRateHz,
      int samplesRead,
      int binCount,
      Map<String, List<double>> channelMags,
    })?
    replayFftPayload = replaySample == null
        ? null
        : _extractReplayFftPayload(replaySample);
    final bool hasReplayFftPayload =
        replayFftPayload != null &&
        replayFftPayload.channelMags.containsKey(_fftChannel);

    // ── Prefer real FFT from bridge; fall back to Dart-computed FFT (mock) ──
    // In replay mode, always derive FFT from replay history so playback affects FFT panel.
    final bool hasFrameFft =
        !_isReplayMode &&
        _bridgeFftBinCount > 1 &&
        _bridgeFftMags.containsKey(_fftChannel);

    List<double> freqs;
    List<double> mags;
    double srHz;
    int samplesUsed;
    String sourceLabel;

    if (hasReplayFftPayload) {
      final List<double> rawMags = replayFftPayload.channelMags[_fftChannel]!;
      mags = rawMags.length > 1 ? rawMags.sublist(1) : rawMags;
      srHz = replayFftPayload.sampleRateHz.toDouble();
      samplesUsed = replayFftPayload.samplesRead;
      final int fftN = DaqFftFrame.nextPow2(
        max(1, replayFftPayload.samplesRead),
      );
      freqs = List<double>.generate(
        mags.length,
        (int k) => (k + 1) * srHz / fftN,
      );
      sourceLabel = 'FFT replay (payload từ log)';
    } else if (hasFrameFft) {
      final List<double> rawMags = _bridgeFftMags[_fftChannel]!;
      // Skip bin 0 (DC) — same as Dart path
      mags = rawMags.length > 1 ? rawMags.sublist(1) : rawMags;
      srHz = _bridgeFftSampleRateHz.toDouble();
      samplesUsed = _bridgeFftSamplesRead;
      final int fftN = DaqFftFrame.nextPow2(_bridgeFftSamplesRead);
      freqs = List<double>.generate(
        mags.length,
        (int k) => (k + 1) * srHz / fftN,
      );
      sourceLabel = _useBridge
          ? 'FFT bridge (phần cứng)'
          : 'FFT demo (mô phỏng block 10kHz)';
    } else {
      final ({
        List<double> freqs,
        List<double> mags,
        double sampleRateHz,
        int samplesUsed,
      })
      r = _computeChannelFft(_fftChannel, 1024);
      freqs = r.freqs;
      mags = r.mags;
      srHz = r.sampleRateHz;
      samplesUsed = r.samplesUsed;
      sourceLabel = _isReplayMode
          ? 'Dart FFT (replay từ log)'
          : 'Dart FFT (demo / vỏ bao RMS)';
    }

    final double peakMag = mags.isEmpty ? 0.0 : mags.reduce(max);
    final double minMag = mags.isEmpty ? 0.0 : mags.reduce(min);
    if (peakMag * 1.2 > _fftMaxY) {
      _fftMaxY = peakMag * 1.2;
    }
    final double safeMaxY = _fftMaxY;
    final List<FlSpot> fftSpots = _buildFftPlotSpots(freqs, mags);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (!compact) ...<Widget>[
          _buildSamplingInfoCard(),
          const SizedBox(height: 8),
        ],
        // Channel selector
        Row(
          children: <Widget>[
            const Text(
              'Kênh FFT:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _channels.map((String ch) {
                    final bool selected = ch == _fftChannel;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(ch, style: const TextStyle(fontSize: 11)),
                        selected: selected,
                        onSelected: (_) {
                          setState(() => _fftChannel = ch);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (srHz > 0)
          Text(
            '$sourceLabel  |  N=$samplesUsed  |  Fs: ${srHz.toStringAsFixed(0)} Hz  |  Δf: ${(srHz / (samplesUsed > 0 ? samplesUsed : 1)).toStringAsFixed(3)} Hz/bin  |  Nyquist: ${(srHz / 2).toStringAsFixed(0)} Hz',
            style: const TextStyle(fontSize: 11, color: Color(0xFF5E6A79)),
          ),
        if (!compact) ...<Widget>[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD8E1EC)),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 4,
              children: <Widget>[
                Text(
                  'THÔNG TIN FFT ${hasReplayFftPayload ? 'replay-payload' : (hasFrameFft ? (_useBridge ? 'bridge' : 'khung-demo') : 'demo-du-phong')}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2F3B4A),
                  ),
                ),
                Text(
                  'N=$samplesUsed',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF4B5B6B),
                  ),
                ),
                Text(
                  'Số bin=${mags.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF4B5B6B),
                  ),
                ),
                Text(
                  'Fs=${srHz.toStringAsFixed(1)} Hz',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF4B5B6B),
                  ),
                ),
                Text(
                  'Nhỏ nhất=${minMag.toStringAsFixed(4)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF4B5B6B),
                  ),
                ),
                Text(
                  'Lớn nhất=${peakMag.toStringAsFixed(4)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF4B5B6B),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        Expanded(
          child: freqs.isEmpty
              ? const Center(
                  child: Text(
                    'Chưa đủ dữ liệu để tính FFT (cần ≥ 8 mẫu)',
                    style: TextStyle(fontSize: 13, color: Color(0xFF5E6A79)),
                  ),
                )
              : LineChart(
                  duration: Duration.zero,
                  curve: Curves.linear,
                  LineChartData(
                    minX: _fftDisplayMinX,
                    maxX: _fftDisplayMaxX,
                    minY: 0,
                    maxY: safeMaxY,
                    clipData: const FlClipData.none(),
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (List<LineBarSpot> spots) {
                          return spots.map((LineBarSpot s) {
                            final double frequencyHz = _fftFrequencyForAxisX(
                              s.x,
                            );
                            return LineTooltipItem(
                              '${frequencyHz.toStringAsFixed(1)} Hz\n${s.y.toStringAsFixed(4)}',
                              const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: safeMaxY > 0.001
                          ? safeMaxY / 4
                          : 0.01,
                      getDrawingHorizontalLine: (_) => const FlLine(
                        color: Color(0xFFCDD8CC),
                        strokeWidth: 0.7,
                        dashArray: <int>[3, 3],
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        axisNameWidget: const Text(
                          'Biên độ',
                          style: TextStyle(fontSize: 10),
                        ),
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 44,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            return Text(
                              value.toStringAsFixed(3),
                              style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFF4A5A6A),
                              ),
                            );
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        axisNameWidget: const Text(
                          'Tần số (Hz)',
                          style: TextStyle(fontSize: 10),
                        ),
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          interval: 0.1,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            final String label = _fftAxisLabelForValue(value);
                            if (label.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF3A4A5A),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    extraLinesData: ExtraLinesData(
                      verticalLines: <VerticalLine>[
                        // Minor log-scale grid lines
                        ...<double>[
                          20,
                          30,
                          40,
                          50,
                          60,
                          70,
                          80,
                          90,
                          200,
                          300,
                          400,
                          500,
                          600,
                          700,
                          800,
                          900,
                          2000,
                          3000,
                          4000,
                        ].map(
                          (double f) => VerticalLine(
                            x: _fftAxisXForFrequency(f),
                            color: const Color(0xFFCDD8C8),
                            strokeWidth: 0.4,
                            dashArray: <int>[2, 4],
                          ),
                        ),
                        // Major decade lines (10, 100, 1000, 5000 Hz)
                        ...<double>[10, 100, 1000, 5000].map(
                          (double f) => VerticalLine(
                            x: _fftAxisXForFrequency(f),
                            color: const Color(0xFF8EA8B8),
                            strokeWidth: 1.0,
                          ),
                        ),
                      ],
                    ),
                    rangeAnnotations: RangeAnnotations(
                      verticalRangeAnnotations: <VerticalRangeAnnotation>[
                        VerticalRangeAnnotation(
                          x1: _fftAxisXForFrequency(200),
                          x2: _fftAxisXForFrequency(700),
                          color: const Color(0xFFF5F9EE),
                        ),
                      ],
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: const Border(
                        left: BorderSide(color: Color(0xFF8EA8B8), width: 1),
                        bottom: BorderSide(color: Color(0xFF8EA8B8), width: 1),
                        right: BorderSide(color: Color(0xFFCDD5D8), width: 0.5),
                        top: BorderSide(color: Color(0xFFCDD5D8), width: 0.5),
                      ),
                    ),
                    lineBarsData: <LineChartBarData>[
                      LineChartBarData(
                        spots: fftSpots,
                        isCurved: false,
                        color: _channelColor(_fftChannel),
                        barWidth: 1.5,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: _channelColor(
                            _fftChannel,
                          ).withValues(alpha: 0.15),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildWavePanel({bool compact = false}) {
    final _LoggedSample? replaySample = _currentReplaySample();
    final ({
      int sampleRateHz,
      int decimStep,
      String unit,
      Map<String, List<double>> channelSamples,
    })?
    replayWavePayload = replaySample == null
        ? null
        : _extractReplayWavePayload(replaySample);
    final bool hasReplayWavePayload =
        replayWavePayload != null &&
        replayWavePayload.channelSamples.containsKey(_waveChannel);

    final List<double>? bridgeSamples = _bridgeWaveSamples[_waveChannel];
    // In replay mode, ignore live bridge waveform and use replay timeline data.
    final bool hasFrameData =
        !_isReplayMode &&
        bridgeSamples != null &&
        bridgeSamples.isNotEmpty &&
        _bridgeWaveSampleRateHz > 0;

    final List<double> mockSamples = _activeCombinedHistory(
      _waveChannel,
    ).map((FlSpot spot) => spot.y).toList();
    if (mockSamples.length > 240) {
      mockSamples.removeRange(0, mockSamples.length - 240);
    }
    final bool hasMockData =
        (_isReplayMode || !_useBridge) && mockSamples.length > 1;

    final bool hasData = hasReplayWavePayload || hasFrameData || hasMockData;
    final List<double> activeSamples = hasReplayWavePayload
        ? replayWavePayload.channelSamples[_waveChannel]!
        : (hasFrameData ? bridgeSamples : mockSamples);
    final int outCount = activeSamples.length;
    final double timeStepMs = hasReplayWavePayload
        ? (replayWavePayload.decimStep /
              replayWavePayload.sampleRateHz *
              1000.0)
        : (hasFrameData
              ? (_bridgeWaveDecimStep / _bridgeWaveSampleRateHz * 1000.0)
              : _sampleIntervalMs.toDouble());
    final double blockMs = hasData
        ? (outCount > 1 ? (outCount - 1) * timeStepMs : timeStepMs)
        : 100.0;
    final double clampedWindowMs = _clampWaveformTimeWindowMs(
      _waveformTimeWindowMs,
    );
    final bool autoExpandWindowForMock =
        !(hasReplayWavePayload || hasFrameData);
    final double displayTimeWindowMs = _clampWaveformTimeWindowMs(
      autoExpandWindowForMock ? max(blockMs, clampedWindowMs) : clampedWindowMs,
    );
    final bool waveInVoltage = hasReplayWavePayload
        ? replayWavePayload.unit.toUpperCase() == 'V'
        : (_useBridge && hasFrameData);
    final double minY = waveInVoltage ? _voltageMin : _chartMinG;
    final double maxY = waveInVoltage ? _voltageMax : _chartMaxG;
    final String yAxisLabel = waveInVoltage ? 'Điện áp (V)' : 'Biên độ (g)';
    final String valueUnit = waveInVoltage ? 'V' : 'g';
    final double effectiveFsHz = timeStepMs > 0 ? 1000.0 / timeStepMs : 0.0;
    final double minSample = hasData ? activeSamples.reduce(min) : 0.0;
    final double maxSample = hasData ? activeSamples.reduce(max) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (!compact) ...<Widget>[
          _buildSamplingInfoCard(),
          const SizedBox(height: 8),
        ],
        Row(
          children: <Widget>[
            const Text(
              'Kênh sóng:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _channels.map((String ch) {
                    final bool selected = ch == _waveChannel;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(ch, style: const TextStyle(fontSize: 11)),
                        selected: selected,
                        onSelected: (_) => setState(() => _waveChannel = ch),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        if (!compact) ...<Widget>[
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              const Text(
                'Thang thời gian (ms):',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _waveformTimeWindowController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                    ),
                  ),
                  onChanged: (String value) {
                    final double? parsed = double.tryParse(value);
                    if (parsed != null && parsed > 0) {
                      setState(() {
                        _waveformTimeWindowMs = _clampWaveformTimeWindowMs(
                          parsed,
                        );
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Tooltip(
                message: 'Tự động (full block)',
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _waveformTimeWindowMs = _clampWaveformTimeWindowMs(
                        blockMs,
                      );
                      _waveformTimeWindowController.text = blockMs
                          .clamp(
                            _waveformTimeWindowMinMs,
                            _waveformTimeWindowMaxMs,
                          )
                          .toStringAsFixed(1);
                    });
                  },
                  icon: const Icon(Icons.auto_awesome, size: 14),
                  label: const Text('Tự động', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Giới hạn thang: ${_waveformTimeWindowMinMs.toStringAsFixed(1)} .. ${_waveformTimeWindowMaxMs.toStringAsFixed(1)} ms',
            style: const TextStyle(fontSize: 11, color: Color(0xFF5E6A79)),
          ),
        ],
        const SizedBox(height: 8),
        if (hasData)
          Text(
            'Dạng sóng (${hasReplayWavePayload ? 'replay-payload' : (hasFrameData ? 'bridge' : 'demo')})  |  N=$outCount  |  Fs: ${effectiveFsHz.toStringAsFixed(1)} Hz'
            '  |  Khối: ${blockMs.toStringAsFixed(1)} ms'
            '  |  Cửa sổ: ${displayTimeWindowMs.toStringAsFixed(1)} ms'
            '${hasReplayWavePayload ? '  |  Giảm mẫu: ×${replayWavePayload.decimStep}' : (hasFrameData ? '  |  Giảm mẫu: ×$_bridgeWaveDecimStep' : '')}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF5E6A79)),
          ),
        if (!compact) ...<Widget>[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD8E1EC)),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 4,
              children: <Widget>[
                Text(
                  'THÔNG TIN SÓNG ${hasReplayWavePayload ? 'replay-payload' : (waveInVoltage ? 'bridge' : 'demo')}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2F3B4A),
                  ),
                ),
                Text(
                  'N=$outCount',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF4B5B6B),
                  ),
                ),
                Text(
                  'Fs=${effectiveFsHz.toStringAsFixed(1)} Hz',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF4B5B6B),
                  ),
                ),
                Text(
                  'Nhỏ nhất=${minSample.toStringAsFixed(4)} $valueUnit',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF4B5B6B),
                  ),
                ),
                Text(
                  'Lớn nhất=${maxSample.toStringAsFixed(4)} $valueUnit',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF4B5B6B),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        Expanded(
          child: !hasData
              ? const Center(
                  child: Text(
                    'Chưa đủ dữ liệu sóng (demo cần >= 2 mẫu)',
                    style: TextStyle(fontSize: 13, color: Color(0xFF5E6A79)),
                  ),
                )
              : LineChart(
                  duration: Duration.zero,
                  curve: Curves.linear,
                  LineChartData(
                    minX: 0,
                    maxX: displayTimeWindowMs,
                    minY: minY,
                    maxY: maxY,
                    clipData: FlClipData.all(),
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (List<LineBarSpot> spots) {
                          return spots.map((LineBarSpot s) {
                            return LineTooltipItem(
                              '${s.x.toStringAsFixed(3)} ms\n${s.y.toStringAsFixed(4)} $valueUnit',
                              const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      getDrawingHorizontalLine: (_) => const FlLine(
                        color: Color(0xFFE8EDF3),
                        strokeWidth: 1,
                      ),
                      getDrawingVerticalLine: (_) => const FlLine(
                        color: Color(0xFFE8EDF3),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        axisNameWidget: Text(
                          yAxisLabel,
                          style: const TextStyle(fontSize: 10),
                        ),
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 44,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            return Text(
                              value.toStringAsFixed(2),
                              style: const TextStyle(fontSize: 9),
                            );
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        axisNameWidget: const Text(
                          'Thời gian (ms)',
                          style: TextStyle(fontSize: 10),
                        ),
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            return Text(
                              value.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 9),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: <LineChartBarData>[
                      LineChartBarData(
                        spots: List<FlSpot>.generate(
                          outCount,
                          (int i) => FlSpot(i * timeStepMs, activeSamples[i]),
                        ),
                        isCurved: false,
                        color: _channelColor(_waveChannel),
                        barWidth: 1.2,
                        dotData: const FlDotData(show: false),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCombinedChartScreen(BoxConstraints constraints) {
    final double chartRange = _chartMaxG - _chartMinG;
    final List<LineChartBarData> lineBars = <LineChartBarData>[];
    final List<String> visibleChannels = _channels
        .where(_isCombinedChannelVisible)
        .toList();
    final double frameNowMs = _isReplayMode && _replayFrameIndex >= 0
        ? _replaySamples[_replayFrameIndex].timestamp.millisecondsSinceEpoch
              .toDouble()
        : DateTime.now().millisecondsSinceEpoch.toDouble();
    final double frameNowSec = frameNowMs / 1000.0;
    final double? fixedWindowSeconds = _combinedFixedWindowSeconds();
    double minVisibleX = fixedWindowSeconds != null
        ? frameNowSec - fixedWindowSeconds
        : frameNowSec;
    double maxVisibleX = frameNowSec;

    for (final String channel in visibleChannels) {
      final List<FlSpot> safeSpots = _visibleSpotsForCombinedChart(
        channel,
        _selectedCombinedWindowMinutes,
        frameNowMs,
      );
      if (fixedWindowSeconds == null) {
        minVisibleX = min(minVisibleX, safeSpots.first.x);
        maxVisibleX = max(maxVisibleX, safeSpots.last.x);
      }

      lineBars.add(
        LineChartBarData(
          spots: safeSpots,
          isCurved: false,
          preventCurveOverShooting: true,
          color: _channelColor(channel),
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }

    final double visibleSpanSeconds = max(maxVisibleX - minVisibleX, 1);
    final double xInterval = _combinedXAxisIntervalSeconds(visibleSpanSeconds);
    final bool isWide = constraints.maxWidth >= 1260;
    final String selectedWindowLabel = _combinedWindowOptions
        .firstWhere(
          (_CombinedWindowOption option) =>
              option.minutes == _selectedCombinedWindowMinutes,
          orElse: () => _combinedWindowOptions.first,
        )
        .label;
    final double replayTotalMs = _replayTotalDurationMs();

    final Widget combinedTimePanel = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildSamplingInfoCard(compact: true),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Text(
              'Hiển thị ${visibleChannels.length}/${_channels.length} kênh',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5E6A79),
              ),
            ),
            const Spacer(),
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onPressed: () {
                setState(() {
                  _hiddenCombinedChannels.clear();
                });
              },
              child: const Text('Hiện tất cả', style: TextStyle(fontSize: 11)),
            ),
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onPressed: () {
                setState(() {
                  _hiddenCombinedChannels
                    ..clear()
                    ..addAll(_channels);
                });
              },
              child: const Text('Bỏ tất cả', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: visibleChannels.isEmpty
              ? const Center(
                  child: Text(
                    'Chưa có kênh nào được chọn',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5E6A79),
                    ),
                  ),
                )
              : LineChart(
                  duration: Duration.zero,
                  curve: Curves.linear,
                  LineChartData(
                    minX: minVisibleX,
                    maxX: maxVisibleX,
                    minY: _chartMinG,
                    maxY: _chartMaxG,
                    clipData: FlClipData.all(),
                    lineTouchData: const LineTouchData(enabled: false),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      horizontalInterval: max(chartRange / 6, 0.05),
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: const Color(0xFFE8EDF3),
                        strokeWidth: 1,
                      ),
                      getDrawingVerticalLine: (_) => const FlLine(
                        color: Color(0xFFE8EDF3),
                        strokeWidth: 1,
                      ),
                    ),
                    extraLinesData: ExtraLinesData(
                      horizontalLines: <HorizontalLine>[
                        HorizontalLine(
                          y: _warningThreshold,
                          color: const Color(0xFFE4A100).withValues(alpha: 0.5),
                          strokeWidth: 1.6,
                          dashArray: <int>[5, 5],
                        ),
                        HorizontalLine(
                          y: _dangerThreshold,
                          color: const Color(0xFFC0392B).withValues(alpha: 0.5),
                          strokeWidth: 1.6,
                          dashArray: <int>[5, 5],
                        ),
                      ],
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        axisNameWidget: Text(
                          _isReplayMode
                              ? 'Thời gian log'
                              : 'Thời gian hệ thống',
                          style: const TextStyle(fontSize: 10),
                        ),
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          interval: xInterval,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            return _buildCombinedBottomTitle(value, meta);
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: lineBars,
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F8FB),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 6,
            children: _channels.map((String channel) {
              final bool selected = _isCombinedChannelVisible(channel);
              return FilterChip(
                selected: selected,
                onSelected: (bool isSelected) {
                  setState(() {
                    if (isSelected) {
                      _hiddenCombinedChannels.remove(channel);
                    } else {
                      _hiddenCombinedChannels.add(channel);
                    }
                  });
                },
                avatar: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _channelColor(channel),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                label: Text(
                  channel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );

    const double replayButtonWidth = 102;

    final Widget replayControlPanel = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD8E3EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                Tooltip(
                  message: 'Chọn file log binary để phát lại',
                  child: SizedBox(
                    width: replayButtonWidth,
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      onPressed: _isLoadingReplayFile
                          ? null
                          : _pickReplayLogFile,
                      icon: const Icon(Icons.folder_open, size: 16),
                      label: Text(
                        _isLoadingReplayFile ? 'Đang nạp' : 'Load log',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Mở thư mục chứa file log',
                  child: SizedBox(
                    width: replayButtonWidth,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      onPressed: _openDataLogFolder,
                      icon: const Icon(Icons.folder_copy_outlined, size: 16),
                      label: const Text('Thư mục'),
                    ),
                  ),
                ),
                if (_isReplayMode) ...<Widget>[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: _isReplayPlaying
                        ? 'Tạm dừng phát lại'
                        : 'Phát lại',
                    child: SizedBox(
                      width: replayButtonWidth,
                      child: FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: const Size(34, 30),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                        ),
                        onPressed: _replaySamples.isEmpty
                            ? null
                            : _toggleReplayPlayback,
                        child: Icon(
                          _isReplayPlaying
                              ? Icons.pause_circle_outline
                              : Icons.play_circle_outline,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Về đầu timeline',
                    child: SizedBox(
                      width: replayButtonWidth,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: const Size(34, 30),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                        ),
                        onPressed: _replaySamples.isEmpty
                            ? null
                            : () => _seekReplayTo(0),
                        child: const Icon(Icons.replay, size: 17),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  PopupMenuButton<double>(
                    enabled: _replaySamples.isNotEmpty,
                    initialValue: _replaySpeed,
                    tooltip: 'Tốc độ phát lại',
                    onSelected: (double speed) {
                      final bool wasPlaying = _isReplayPlaying;
                      if (wasPlaying) {
                        _pauseReplay();
                      }
                      setState(() {
                        _replaySpeed = speed;
                      });
                      if (wasPlaying) {
                        _startReplayPlayback();
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      return _replaySpeedOptions.map((double speed) {
                        return PopupMenuItem<double>(
                          value: speed,
                          child: Text(
                            '${speed.toStringAsFixed(speed.truncateToDouble() == speed ? 0 : 1)}x',
                          ),
                        );
                      }).toList();
                    },
                    child: SizedBox(
                      width: replayButtonWidth,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFB6CCE2)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Icon(Icons.speed, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${_replaySpeed.toStringAsFixed(_replaySpeed.truncateToDouble() == _replaySpeed ? 0 : 1)}x',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Thoát chế độ phát lại',
                    child: SizedBox(
                      width: replayButtonWidth,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: const Size(34, 30),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                        ),
                        onPressed: _exitReplayMode,
                        child: const Icon(Icons.close, size: 16),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_isLoadingReplayFile) ...<Widget>[
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: LinearProgressIndicator(
                    value: _replayLoadProgress.clamp(0.0, 1.0).toDouble(),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(8),
                    backgroundColor: const Color(0xFFE3EAF3),
                    color: const Color(0xFF0B4F8A),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(_replayLoadProgress * 100).clamp(0.0, 100.0).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E3C4A),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 2),
          if (_isReplayMode) ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _replayFilePath == null
                        ? 'Replay'
                        : _fileNameFromPath(_replayFilePath!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF314556),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_formatDurationLabel(Duration(milliseconds: _replayPositionMs.round()))}/${_formatDurationLabel(Duration(milliseconds: replayTotalMs.round()))}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF5E6A79),
                  ),
                ),
                if (_replayFrameIndex >= 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      '${_replayFrameIndex + 1}/${_replaySamples.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF5E6A79),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(
              height: 26,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                    disabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 10,
                  ),
                ),
                child: Slider(
                  min: 0,
                  max: max(replayTotalMs, 1),
                  value: _replaySamples.isEmpty
                      ? 0
                      : _replayPositionMs.clamp(0, max(replayTotalMs, 1)),
                  onChanged: _replaySamples.isEmpty
                      ? null
                      : (double value) {
                          if (_isReplayPlaying) {
                            _pauseReplay();
                          }
                          _seekReplayTo(value);
                        },
                ),
              ),
            ),
          ] else
            const Text(
              'Chế độ live',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4D5C6B),
              ),
            ),
        ],
      ),
    );

    final Widget combinedHeaderPanel = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: const Color(0xFFD9EAF7),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(
                Icons.multiline_chart,
                size: 15,
                color: Color(0xFF0B4F8A),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Kênh tổng hợp',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  Text(
                    _isReplayMode
                        ? 'Phát lại ${visibleChannels.length} kênh từ file log'
                        : 'Giám sát đồng thời ${visibleChannels.length} kênh đang hiển thị',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF5E6A79),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            _dashboardInfoPill(
              icon: Icons.history,
              label: 'Cửa sổ',
              value: selectedWindowLabel,
            ),
            _dashboardInfoPill(
              icon: Icons.tune,
              label: 'Dải đo',
              value:
                  '${_chartMinG.toStringAsFixed(2)}..${_chartMaxG.toStringAsFixed(2)} g',
            ),
            _dashboardInfoPill(
              icon: Icons.warning_amber_rounded,
              label: 'Ngưỡng',
              value:
                  '${_warningThreshold.toStringAsFixed(2)}/${_dangerThreshold.toStringAsFixed(2)} g',
            ),
            _dashboardInfoPill(
              icon: _isReplayMode
                  ? Icons.movie_creation_outlined
                  : Icons.sensors,
              label: 'Nguồn',
              value: _isReplayMode
                  ? 'Replay log'
                  : (_useBridge ? 'Bridge live' : 'Demo live'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        replayControlPanel,
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F8FC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD8E3EE)),
          ),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _combinedWindowOptions.map((
              _CombinedWindowOption option,
            ) {
              final bool selected =
                  _selectedCombinedWindowMinutes == option.minutes;
              return ChoiceChip(
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                label: Text(option.label),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    _selectedCombinedWindowMinutes = option.minutes;
                  });
                },
              );
            }).toList(),
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (!isWide) ...<Widget>[
                combinedHeaderPanel,
                const SizedBox(height: 4),
              ],
              Expanded(
                child: isWide
                    ? Row(
                        children: <Widget>[
                          Expanded(
                            flex: 7,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                combinedHeaderPanel,
                                const SizedBox(height: 6),
                                Expanded(child: combinedTimePanel),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: <Widget>[
                                Expanded(
                                  child: _panelShell(
                                    title: 'FFT phổ tần',
                                    child: _buildFftPanel(compact: true),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: _panelShell(
                                    title: 'Dạng sóng',
                                    child: _buildWavePanel(compact: true),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: <Widget>[
                          Expanded(flex: 4, child: combinedTimePanel),
                          const SizedBox(height: 10),
                          Expanded(
                            flex: 3,
                            child: _panelShell(
                              title: 'FFT phổ tần',
                              child: _buildFftPanel(compact: true),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            flex: 3,
                            child: _panelShell(
                              title: 'Dạng sóng',
                              child: _buildWavePanel(compact: true),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dashboardInfoPill({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8E3EE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: const Color(0xFF0B4F8A)),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF466079),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF22384D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelShell({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFCFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDCE6F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2A3E53),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildSettingsScreen() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        _buildSettingsSectionCard(
          icon: Icons.settings_input_component,
          title: 'Đầu vào DAQ',
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _voltageMinController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Giá trị vào nhỏ nhất',
                      hintText: '-10',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _voltageMaxController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Giá trị vào lớn nhất',
                      hintText: '10',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Dải đo hiện tại: ${_voltageMin.toStringAsFixed(2)} ${_bridgeRawUnitLabel()} .. ${_voltageMax.toStringAsFixed(2)} ${_bridgeRawUnitLabel()}',
            ),
            const SizedBox(height: 6),
            Text(
              'Tham số bridge: $_bridgeArguments',
              style: const TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            _buildSettingsActionBar(
              onReset: _resetDaqSamplingDefaults,
              applyButtons: <Widget>[
                FilledButton.icon(
                  onPressed: _applyVoltageRange,
                  icon: const Icon(Icons.save),
                  label: const Text('Áp dụng dải đo'),
                ),
              ],
            ),
          ],
        ),
        _buildSettingsSectionCard(
          icon: Icons.speed,
          title: 'Lấy mẫu DAQ',
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _sampleRateController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tần số lấy mẫu (Hz)',
                      hintText: '10000',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _samplesPerReadController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Số mẫu mỗi lần đọc',
                      hintText: '1000',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Lấy mẫu hiện tại: $_sampleRateHz Hz, $_samplesPerRead mẫu/lần đọc',
            ),
            const SizedBox(height: 12),
            _buildSettingsActionBar(
              onReset: _resetDaqSamplingDefaults,
              applyButtons: <Widget>[
                FilledButton.icon(
                  onPressed: _applySamplingSettings,
                  icon: const Icon(Icons.speed),
                  label: const Text('Áp dụng lấy mẫu'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            _buildControlPanel(embedded: true),
          ],
        ),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool isWideLayout = constraints.maxWidth >= 980;

            final Widget sensorCard = _buildSettingsSectionCard(
              icon: Icons.sensors,
              title: 'Cảm biến',
              children: <Widget>[
                DropdownButtonFormField<String>(
                  value: _selectedAccelPresetId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Mẫu cảm biến'),
                  items: _accelPresets
                      .map(
                        (_AccelSensorPreset preset) => DropdownMenuItem<String>(
                          value: preset.id,
                          child: Text(preset.label),
                        ),
                      )
                      .toList(),
                  onChanged: (String? value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedAccelPresetId = value;
                      final _AccelSensorPreset selected =
                          _selectedAccelPreset();
                      if (!selected.isCustom) {
                        _accelSensitivityController.text = selected
                            .sensitivityMvPerG
                            .toString();
                      }
                    });
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _accelSensitivityController,
                  enabled: _selectedAccelPreset().isCustom,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: false,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Độ nhạy (mV/g)',
                    hintText: '100',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Độ nhạy đang dùng: ${_effectiveAccelSensitivityMvPerG().toStringAsFixed(2)} mV/g',
                ),
                if (isWideLayout) const Spacer(),
                const SizedBox(height: 12),
                _buildSettingsActionBar(
                  onReset: _resetSensorDefaults,
                  applyButtons: <Widget>[
                    FilledButton.icon(
                      onPressed: _applyAccelPresetAndSensitivity,
                      icon: const Icon(Icons.sensors),
                      label: const Text('Áp dụng mẫu cảm biến'),
                    ),
                  ],
                ),
              ],
            );

            final Widget aiCard = _buildSettingsSectionCard(
              icon: Icons.tune,
              title: 'Chế độ AI',
              children: <Widget>[
                DropdownButtonFormField<BridgeAiChannelMode>(
                  value: _aiChannelMode,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Chế độ kênh AI',
                  ),
                  items: const <DropdownMenuItem<BridgeAiChannelMode>>[
                    DropdownMenuItem<BridgeAiChannelMode>(
                      value: BridgeAiChannelMode.voltage,
                      child: Text('DAQmxCreateAIVoltageChan'),
                    ),
                    DropdownMenuItem<BridgeAiChannelMode>(
                      value: BridgeAiChannelMode.accel,
                      child: Text('DAQmxCreateAIAccelChan'),
                    ),
                  ],
                  onChanged: (BridgeAiChannelMode? mode) {
                    if (mode == null) {
                      return;
                    }
                    setState(() {
                      _aiChannelMode = mode;
                    });
                  },
                ),
                const SizedBox(height: 10),
                Text('Hàm AI hiện tại: ${_aiModeLabel(_aiChannelMode)}'),
                if (isWideLayout) const Spacer(),
                const SizedBox(height: 12),
                _buildSettingsActionBar(
                  onReset: _resetAiModeDefault,
                  applyButtons: <Widget>[
                    FilledButton.icon(
                      onPressed: _applyAiChannelMode,
                      icon: const Icon(Icons.tune),
                      label: const Text('Áp dụng chế độ AI'),
                    ),
                  ],
                ),
              ],
            );

            if (isWideLayout) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: SizedBox(
                        height: double.infinity,
                        child: sensorCard,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(height: double.infinity, child: aiCard),
                    ),
                  ],
                ),
              );
            }

            return Column(children: <Widget>[sensorCard, aiCard]);
          },
        ),
        _buildSettingsSectionCard(
          icon: Icons.stacked_line_chart,
          title: 'Hiển thị và cảnh báo',
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _chartMinController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Giá trị nhỏ nhất của đồ thị (g)',
                      hintText: '0.0',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _chartMaxController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Giá trị lớn nhất của đồ thị (g)',
                      hintText: '1.2',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Thang đo hiện tại: ${_chartMinG.toStringAsFixed(2)} g .. ${_chartMaxG.toStringAsFixed(2)} g',
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _waveformTimeWindowMinController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: false,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Scale ms nhỏ nhất (kênh sóng)',
                      hintText: '20',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _waveformTimeWindowMaxController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: false,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Scale ms lớn nhất (kênh sóng)',
                      hintText: '2000',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Giới hạn sóng hiện tại: ${_waveformTimeWindowMinMs.toStringAsFixed(1)} .. ${_waveformTimeWindowMaxMs.toStringAsFixed(1)} ms | Cửa sổ đang dùng: ${_waveformTimeWindowMs.toStringAsFixed(1)} ms',
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: _thresholdEditor(
                    title: 'Ngưỡng cảnh báo',
                    value: _warningThreshold,
                    onChanged: (double value) {
                      setState(() {
                        _warningThreshold = value;
                        if (_warningThreshold >= _dangerThreshold) {
                          _dangerThreshold = (_warningThreshold + 0.05).clamp(
                            _chartMinG,
                            _chartMaxG,
                          );
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _thresholdEditor(
                    title: 'Ngưỡng cảnh báo 2',
                    value: _dangerThreshold,
                    onChanged: (double value) {
                      setState(() {
                        _dangerThreshold = value;
                        if (_dangerThreshold <= _warningThreshold) {
                          _warningThreshold = (_dangerThreshold - 0.05).clamp(
                            _chartMinG,
                            _chartMaxG,
                          );
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSettingsActionBar(
              onReset: _resetDisplayAlertDefaults,
              applyButtons: <Widget>[
                FilledButton.icon(
                  onPressed: _applyChartScale,
                  icon: const Icon(Icons.stacked_line_chart),
                  label: const Text('Áp dụng thang đo'),
                ),
                FilledButton.icon(
                  onPressed: _applyWaveformScaleRange,
                  icon: const Icon(Icons.show_chart),
                  label: const Text('Áp dụng scale sóng'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingsActionBar({
    required VoidCallback onReset,
    required List<Widget> applyButtons,
  }) {
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: <Widget>[
          ...applyButtons,
          OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Đặt lại mặc định'),
          ),
        ],
      ),
    );
  }

  void _resetDaqSamplingDefaults() {
    setState(() {
      _voltageMin = -10.0;
      _voltageMax = 10.0;
      _sampleRateHz = 10000;
      _samplesPerRead = 1000;

      _voltageMinController.text = _voltageMin.toString();
      _voltageMaxController.text = _voltageMax.toString();
      _sampleRateController.text = _sampleRateHz.toString();
      _samplesPerReadController.text = _samplesPerRead.toString();

      _bridgeArguments = _upsertBridgeFlag(
        _bridgeArguments,
        '--min',
        _voltageMin.toString(),
      );
      _bridgeArguments = _upsertBridgeFlag(
        _bridgeArguments,
        '--max',
        _voltageMax.toString(),
      );
      _bridgeArguments = _upsertBridgeFlag(
        _bridgeArguments,
        '--rate',
        _sampleRateHz.toString(),
      );
      _bridgeArguments = _upsertBridgeFlag(
        _bridgeArguments,
        '--samples',
        _samplesPerRead.toString(),
      );
      _bridgeArgsController.text = _bridgeArguments;

      _eventLogs.insert(
        0,
        '[${DateTime.now().toLocal()}] Đặt lại cài đặt đầu vào và lấy mẫu về mặc định.',
      );
      _trimLogs();
    });

    _acquisitionService.setMockSamplingConfig(
      sampleRateHz: _sampleRateHz,
      samplesPerRead: _samplesPerRead,
    );
    if (!_useBridge) {
      _startAcquisition();
    }
    unawaited(_saveSettings());
  }

  void _resetSensorDefaults() {
    setState(() {
      _selectedAccelPresetId = 'EX607A01';
      _customAccelSensitivityMvPerG = 100.0;

      _accelSensitivityController.text = _customAccelSensitivityMvPerG
          .toString();

      _bridgeArguments = _upsertBridgeFlag(
        _bridgeArguments,
        '--accel-sens',
        _effectiveAccelSensitivityMvPerG().toString(),
      );
      _bridgeArgsController.text = _bridgeArguments;

      _eventLogs.insert(
        0,
        '[${DateTime.now().toLocal()}] Đặt lại cài đặt cảm biến về mặc định.',
      );
      _trimLogs();
    });

    unawaited(_saveSettings());
  }

  void _resetAiModeDefault() {
    setState(() {
      _aiChannelMode = BridgeAiChannelMode.voltage;

      _bridgeArguments = _upsertBridgeFlag(
        _bridgeArguments,
        '--ai-mode',
        _aiModeFlagValue(_aiChannelMode),
      );
      _bridgeArgsController.text = _bridgeArguments;

      _eventLogs.insert(
        0,
        '[${DateTime.now().toLocal()}] Đặt lại chế độ AI về mặc định.',
      );
      _trimLogs();
    });

    _syncAcquisitionSignalUnit();
    unawaited(_saveSettings());
  }

  void _resetDisplayAlertDefaults() {
    setState(() {
      _chartMinG = 0.0;
      _chartMaxG = 1.2;
      _warningThreshold = 0.65;
      _dangerThreshold = 0.85;
      _waveformTimeWindowMinMs = 20.0;
      _waveformTimeWindowMaxMs = 2000.0;
      _waveformTimeWindowMs = _clampWaveformTimeWindowMs(200.0);

      _chartMinController.text = _chartMinG.toString();
      _chartMaxController.text = _chartMaxG.toString();
      _waveformTimeWindowMinController.text = _waveformTimeWindowMinMs
          .toString();
      _waveformTimeWindowMaxController.text = _waveformTimeWindowMaxMs
          .toString();
      _waveformTimeWindowController.text = _waveformTimeWindowMs.toString();

      _eventLogs.insert(
        0,
        '[${DateTime.now().toLocal()}] Đặt lại thang đo đồ thị, scale sóng và ngưỡng cảnh báo về mặc định.',
      );
      _trimLogs();
    });

    unawaited(_saveSettings());
  }

  Widget _buildSettingsSectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 18, color: const Color(0xFF005A9C)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSamplingInfoCard({bool compact = false}) {
    final String actualSamplingLabel = _useBridge
        ? (_isConnected &&
                  _actualSampleRateHz != null &&
                  _actualSamplesPerRead != null
              ? 'Thực tế: ${_actualSampleRateHz!} Hz | ${_actualSamplesPerRead!} mẫu/lần đọc'
              : 'Thực tế: đang chờ dữ liệu bridge...')
        : 'Thực tế: nguồn demo';

    return Card(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 6 : 9,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.speed,
                  size: compact ? 15 : 18,
                  color: const Color(0xFF005A9C),
                ),
                SizedBox(width: compact ? 6 : 8),
                Expanded(
                  child: Text(
                    'Cấu hình: $_sampleRateHz Hz | $_samplesPerRead mẫu/lần đọc',
                    style: TextStyle(
                      fontSize: compact ? 11 : 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2F3B4A),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 2 : 4),
            Text(
              actualSamplingLabel,
              style: TextStyle(
                fontSize: compact ? 10.5 : 11.5,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF5E6A79),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel({bool embedded = false}) {
    final ButtonStyle presetButtonStyle = OutlinedButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    );

    final Widget content = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        OutlinedButton(
          style: presetButtonStyle,
          onPressed: () {
            _applyBridgePreset(
              '--stream --rate 5000 --samples 500 --min -10 --max 10 --ai-mode voltage cDAQ9181-1E439C1Mod1/ai0:15',
              'On dinh 16 kenh',
            );
          },
          child: const Text('Ổn định'),
        ),
        OutlinedButton(
          style: presetButtonStyle,
          onPressed: () {
            _applyBridgePreset(
              '--stream --rate 20000 --samples 400 --min -10 --max 10 --ai-mode voltage cDAQ9181-1E439C1Mod1/ai0:15',
              'Bat xung nhanh 20ms',
            );
          },
          child: const Text('Nhanh'),
        ),
        OutlinedButton(
          style: presetButtonStyle,
          onPressed: () {
            _applyBridgePreset(
              '--stream --rate 2500 --samples 250 --min -10 --max 10 --ai-mode voltage cDAQ9181-1E439C1Mod1/ai0:15',
              'Nhe CPU',
            );
          },
          child: const Text('Nhẹ CPU'),
        ),
      ],
    );

    if (embedded) {
      return content;
    }

    return Card(
      child: Padding(padding: const EdgeInsets.all(14), child: content),
    );
  }

  Widget _thresholdEditor({
    required String title,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    final double sliderMin = _chartMinG;
    final double sliderMax = _chartMaxG;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('$title: ${value.toStringAsFixed(2)} g'),
        Slider(
          min: sliderMin,
          max: sliderMax,
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSensorGrid(double frameNowMs) {
    final List<String> visibleChannels = _channels
        .where(_isChannelVisible)
        .toList();

    if (visibleChannels.isEmpty) {
      return Card(
        child: Center(
          child: Text(
            'Chưa có kênh nào được chọn',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF5E6A79).withValues(alpha: 0.9),
            ),
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: GridView.builder(
          itemCount: visibleChannels.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            mainAxisExtent: 260,
          ),
          itemBuilder: (BuildContext context, int index) {
            final String channel = visibleChannels[index];
            final double value = _latestValues[channel] ?? 0;
            final double rawRmsVolts = _latestRawRmsVolts[channel] ?? 0;
            final SensorState state =
                _lastStates[channel] ?? SensorState.normal;
            final Color color = _stateColor(state);
            final double chartRange = _chartMaxG - _chartMinG;
            final List<FlSpot> safeSpots = _visibleSpotsForChannelChart(
              channel,
              frameNowMs,
            );
            final double chartMaxX = max(1, safeSpots.last.x);

            return Container(
              clipBehavior: Clip.antiAlias,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        channel,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        _stateLabel(state).toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text('${value.toStringAsFixed(3)} g'),
                  Text(
                    'RMS ${rawRmsVolts.toStringAsFixed(4)} ${_bridgeRawUnitLabel()}',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  if (_aiChannelMode == BridgeAiChannelMode.voltage)
                    Text(
                      'Range: ${_voltageMin.toStringAsFixed(1)} to ${_voltageMax.toStringAsFixed(1)} V',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF666666),
                      ),
                    )
                  else
                    Text(
                      'Accel sensitivity: ${_effectiveAccelSensitivityMvPerG().toStringAsFixed(1)} mV/g',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF666666),
                      ),
                    ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: ((value - _chartMinG) / chartRange).clamp(0, 1),
                    backgroundColor: const Color(0xFFE9EEF5),
                    color: color,
                    minHeight: 7,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Stack(
                      children: <Widget>[
                        Column(
                          children: <Widget>[
                            Expanded(
                              child: LineChart(
                                duration: Duration.zero,
                                curve: Curves.linear,
                                LineChartData(
                                  minX: 0,
                                  maxX: chartMaxX,
                                  minY: _chartMinG,
                                  maxY: _chartMaxG,
                                  clipData: FlClipData.all(),
                                  lineTouchData: const LineTouchData(
                                    enabled: false,
                                  ),
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    horizontalInterval: max(
                                      chartRange / 6,
                                      0.05,
                                    ),
                                    getDrawingHorizontalLine: (_) => FlLine(
                                      color: const Color(0xFFE8EDF3),
                                      strokeWidth: 1,
                                    ),
                                  ),
                                  extraLinesData: ExtraLinesData(
                                    horizontalLines: <HorizontalLine>[
                                      HorizontalLine(
                                        y: _warningThreshold,
                                        color: const Color(
                                          0xFFE4A100,
                                        ).withValues(alpha: 0.4),
                                        strokeWidth: 1.5,
                                        dashArray: <int>[5, 5],
                                      ),
                                      HorizontalLine(
                                        y: _dangerThreshold,
                                        color: const Color(
                                          0xFFC0392B,
                                        ).withValues(alpha: 0.4),
                                        strokeWidth: 1.5,
                                        dashArray: <int>[5, 5],
                                      ),
                                    ],
                                  ),
                                  titlesData: const FlTitlesData(show: false),
                                  borderData: FlBorderData(show: false),
                                  lineBarsData: <LineChartBarData>[
                                    LineChartBarData(
                                      spots: safeSpots,
                                      isCurved: false,
                                      preventCurveOverShooting: true,
                                      color: color,
                                      barWidth: 2.2,
                                      dotData: const FlDotData(show: false),
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color: color.withValues(alpha: 0.1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F8FB),
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(8),
                                  bottomRight: Radius.circular(8),
                                ),
                                border: Border(
                                  top: BorderSide(
                                    color: color.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Text(
                                    'V: ${_voltageMin.toStringAsFixed(1)}~${_voltageMax.toStringAsFixed(1)} V',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                  Row(
                                    children: <Widget>[
                                      Container(
                                        width: 3,
                                        height: 3,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFE4A100),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'W: ${_warningThreshold.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 8,
                                          color: Color(0xFFE4A100),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 3,
                                        height: 3,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFC0392B),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'D: ${_dangerThreshold.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 8,
                                          color: Color(0xFFC0392B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEventPanel() {
    final List<String> filteredLogs = _eventLogs
        .where((String message) {
          if (_selectedEventLogFilter == _EventLogFilter.all) {
            return true;
          }
          final _EventLogLevel level = _eventLogLevel(message);
          return (_selectedEventLogFilter == _EventLogFilter.info &&
                  level == _EventLogLevel.info) ||
              (_selectedEventLogFilter == _EventLogFilter.warning &&
                  level == _EventLogLevel.warning) ||
              (_selectedEventLogFilter == _EventLogFilter.danger &&
                  level == _EventLogLevel.danger);
        })
        .toList(growable: false);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(Icons.event_note, size: 18, color: Color(0xFF005A9C)),
                SizedBox(width: 8),
                Text(
                  'Nhật ký sự kiện',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _EventLogFilter.values.map((_EventLogFilter filter) {
                final bool selected = _selectedEventLogFilter == filter;
                final _EventLogLevel colorSource = switch (filter) {
                  _EventLogFilter.all => _EventLogLevel.info,
                  _EventLogFilter.info => _EventLogLevel.info,
                  _EventLogFilter.warning => _EventLogLevel.warning,
                  _EventLogFilter.danger => _EventLogLevel.danger,
                };
                final Color color = _eventLogLevelColor(colorSource);
                return ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  label: Text(_eventLogFilterLabel(filter)),
                  avatar: Icon(
                    _eventLogFilterIcon(filter),
                    size: 14,
                    color: selected ? color : const Color(0xFF6B7A89),
                  ),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _selectedEventLogFilter = filter;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filteredLogs.isEmpty
                  ? Center(
                      child: Text(
                        _eventLogs.isEmpty
                            ? 'Chưa có sự kiện'
                            : 'Không có sự kiện phù hợp bộ lọc',
                      ),
                    )
                  : ListView.separated(
                      itemCount: filteredLogs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (BuildContext context, int index) {
                        final String message = filteredLogs[index];
                        final _EventLogLevel level = _eventLogLevel(message);
                        final Color levelColor = _eventLogLevelColor(level);

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: levelColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: levelColor.withValues(alpha: 0.24),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Icon(
                                _eventLogLevelIcon(level),
                                size: 15,
                                color: levelColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  message,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.3,
                                    color: const Color(0xFF2E3C4A),
                                    fontWeight: level == _EventLogLevel.danger
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  _EventLogLevel _eventLogLevel(String message) {
    final String normalized = message.toLowerCase();
    if (normalized.contains('error') ||
        normalized.contains('failed') ||
        normalized.contains('bridge exited') ||
        normalized.contains('status code') ||
        normalized.contains('exception') ||
        normalized.contains('timeout') ||
        normalized.contains('khong hop le') ||
        normalized.contains('invalid')) {
      return _EventLogLevel.danger;
    }
    if (normalized.contains('warning') ||
        normalized.contains('fallback') ||
        normalized.contains('reconnect') ||
        normalized.contains('disconnect') ||
        normalized.contains('threshold') ||
        normalized.contains('unsupported')) {
      return _EventLogLevel.warning;
    }
    return _EventLogLevel.info;
  }

  String _eventLogFilterLabel(_EventLogFilter filter) {
    switch (filter) {
      case _EventLogFilter.all:
        return 'Tất cả';
      case _EventLogFilter.info:
        return 'Info';
      case _EventLogFilter.warning:
        return 'Warning';
      case _EventLogFilter.danger:
        return 'Danger';
    }
  }

  IconData _eventLogFilterIcon(_EventLogFilter filter) {
    switch (filter) {
      case _EventLogFilter.all:
        return Icons.filter_alt_outlined;
      case _EventLogFilter.info:
        return Icons.info_outline;
      case _EventLogFilter.warning:
        return Icons.warning_amber_rounded;
      case _EventLogFilter.danger:
        return Icons.error_outline;
    }
  }

  Color _eventLogLevelColor(_EventLogLevel level) {
    switch (level) {
      case _EventLogLevel.info:
        return const Color(0xFF0B4F8A);
      case _EventLogLevel.warning:
        return const Color(0xFFE4A100);
      case _EventLogLevel.danger:
        return const Color(0xFFC0392B);
    }
  }

  IconData _eventLogLevelIcon(_EventLogLevel level) {
    switch (level) {
      case _EventLogLevel.info:
        return Icons.info_outline;
      case _EventLogLevel.warning:
        return Icons.warning_amber_rounded;
      case _EventLogLevel.danger:
        return Icons.error_outline;
    }
  }
}
