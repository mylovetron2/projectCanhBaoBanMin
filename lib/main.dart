import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cảnh báo bắn mìn - Địa vật lý Giếng Khoang',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF005A9C),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F8FB),
        useMaterial3: true,
      ),
      home: const MineAlertDashboard(),
    );
  }
}

enum SensorState { normal, warning, danger }

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

  final List<String> _channels = List.generate(16, (index) => 'AI$index');
  final Map<String, List<FlSpot>> _history = <String, List<FlSpot>>{};
  final Map<String, double> _latestValues = <String, double>{};
  final Map<String, double> _latestRawRmsVolts = <String, double>{};
  final Map<String, SensorState> _lastStates = <String, SensorState>{};
  final List<String> _eventLogs = <String>[];

  late final DataAcquisitionService _acquisitionService;
  StreamSubscription<AcquisitionSample>? _sampleSub;
  StreamSubscription<String>? _statusSub;

  bool _isRunning = true;
  bool _isConnected = false;
  bool _useBridge = true;
  bool _autoRecoveringAccelUnsupported = false;
  DateTime? _lastAutoFallbackAt;
  String _lastAutoFallbackReason = '';
  int _selectedScreenIndex = 0;
  int _selectedCombinedWindowMinutes = -1;
  int _combinedViewTab = 0; // 0 = time domain, 1 = FFT, 2 = waveform
  String _fftChannel = 'AI0';

  // Latest FFT from C bridge (bridge mode only; empty in mock mode)
  final Map<String, List<double>> _bridgeFftMags = <String, List<double>>{};
  int _bridgeFftSampleRateHz = 0;
  int _bridgeFftBinCount = 0;
  int _bridgeFftSamplesRead = 0;
  StreamSubscription<DaqFftFrame>? _fftSub;

  // Latest raw waveform from C bridge (bridge mode only)
  final Map<String, List<double>> _bridgeWaveSamples = <String, List<double>>{};
  int _bridgeWaveSampleRateHz = 0;
  int _bridgeWaveDecimStep = 1;
  String _waveChannel = 'AI0';
  double _waveformTimeWindowMs = 100.0; // User-configurable time axis scale
  StreamSubscription<DaqWaveFrame>? _waveSub;
  final Set<String> _hiddenChannels = <String>{};
  final Set<String> _hiddenCombinedChannels = <String>{};
  double _warningThreshold = 0.65;
  double _dangerThreshold = 0.85;
  int _sampleIntervalMs = 500;
  double _voltageMin = -10.0;
  double _voltageMax = 10.0;
  double _chartMinG = 0.0;
  double _chartMaxG = 1.2;
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

  static const Duration _historyRetention = Duration(hours: 4);
  static const int _combinedRealtimeSeconds = 60;
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
        _CombinedWindowOption(label: 'Realtime', minutes: -1),
        _CombinedWindowOption(label: '15p', minutes: 15),
        _CombinedWindowOption(label: '30p', minutes: 30),
        _CombinedWindowOption(label: '1h', minutes: 60),
        _CombinedWindowOption(label: '2h', minutes: 120),
        _CombinedWindowOption(label: '4h', minutes: 240),
        _CombinedWindowOption(label: 'All', minutes: 0),
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
    _acquisitionService = DataAcquisitionService(channels: _channels);
    _syncAcquisitionSignalUnit();

    for (final String channel in _channels) {
      _history[channel] = <FlSpot>[];
      _latestValues[channel] = 0;
      _latestRawRmsVolts[channel] = 0;
      _lastStates[channel] = SensorState.normal;
    }

    _sampleSub = _acquisitionService.samples.listen(_onAcquisitionSample);
    _fftSub = _acquisitionService.fftFrames.listen(_onBridgeFftFrame);
    _waveSub = _acquisitionService.waveFrames.listen(_onBridgeWaveFrame);
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
    _fftSub?.cancel();
    _waveSub?.cancel();
    _statusSub?.cancel();
    _syncSettingsFromInputs();
    unawaited(_saveSettings());
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

  void _resetAutoFallbackStatus() {
    setState(() {
      _lastAutoFallbackAt = null;
      _lastAutoFallbackReason = '';
      _eventLogs.insert(
        0,
        '[${DateTime.now().toLocal()}] Auto fallback status cleared by user.',
      );
      _trimLogs();
    });
    unawaited(_saveSettings());
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
    await prefs.setInt(_prefSampleRateHz, _sampleRateHz);
    await prefs.setInt(_prefSamplesPerRead, _samplesPerRead);
    await prefs.setString(_prefAiChannelMode, _aiModeFlagValue(_aiChannelMode));
    await prefs.setString(_prefAccelPresetId, _selectedAccelPresetId);
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
        '[${DateTime.now().toLocal()}] Acquisition ${_isRunning ? 'started' : 'paused'}',
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
          title: const Text('Disconnect data source?'),
          content: Text(
            _useBridge
                ? 'Stop the NI-DAQmx bridge process and disconnect now?'
                : 'Disconnect mock link now?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Disconnect'),
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }

  Future<void> _connectConnection({String trigger = 'user action'}) async {
    if (!_useBridge) {
      setState(() {
        _isConnected = true;
        _actualSampleRateHz = null;
        _actualSamplesPerRead = null;
        _acquisitionService.setMockConnected(true);
        _eventLogs.insert(
          0,
          '[${DateTime.now().toLocal()}] Mock link connected ($trigger)',
        );
        _trimLogs();
      });
      _showActionMessage('Mock connected.');
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
            '[${DateTime.now().toLocal()}] Bridge executable path is empty. Stay in mock mode or set a valid path.',
          );
          _isConnected = false;
          _trimLogs();
        });
        _showActionMessage('Bridge executable path is empty.');
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
          '[${DateTime.now().toLocal()}] Bridge connected ($trigger)',
        );
        _trimLogs();
      });
      _showActionMessage('Bridge connected.');
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
          '[${DateTime.now().toLocal()}] Bridge connect failed: $error',
        );
        _trimLogs();
      });
      _showActionMessage('Bridge connect failed.');
    }
  }

  Future<void> _disconnectConnection({String reason = 'user action'}) async {
    if (!_useBridge) {
      setState(() {
        _isConnected = false;
        _actualSampleRateHz = null;
        _actualSamplesPerRead = null;
        _acquisitionService.setMockConnected(false);
        _eventLogs.insert(
          0,
          '[${DateTime.now().toLocal()}] Mock link disconnected ($reason)',
        );
        _trimLogs();
      });
      _showActionMessage('Mock disconnected. Reason: $reason');
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
          '[${DateTime.now().toLocal()}] Bridge already disconnected ($reason)',
        );
        _trimLogs();
      });
      _showActionMessage('Bridge already disconnected.');
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
        '[${DateTime.now().toLocal()}] Bridge disconnected ($reason)',
      );
      _trimLogs();
    });
    _showActionMessage('Bridge disconnected. Reason: $reason');
  }

  Future<void> _toggleConnection() async {
    if (_isConnected) {
      final bool shouldDisconnect = await _confirmDisconnectConnection();
      if (!shouldDisconnect) {
        _showActionMessage('Disconnect canceled.');
        return;
      }
      await _disconnectConnection(reason: 'toolbar toggle');
      return;
    }
    await _connectConnection(trigger: 'toolbar toggle');
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
      await _disconnectConnection(reason: 'switched to mock source');
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
        '[${DateTime.now().toLocal()}] Data source: ${enabled ? 'NI-DAQmx bridge (multi-channel)' : 'Mock'}',
      );
    });
    unawaited(_saveSettings());

    if (enabled) {
      await _connectConnection(trigger: 'switched to bridge source');
    }
  }

  void _onBridgeFftFrame(DaqFftFrame frame) {
    if (!_isRunning || !mounted) return;
    setState(() {
      _bridgeFftSampleRateHz = frame.sampleRateHz;
      _bridgeFftBinCount = frame.binCount;
      _bridgeFftSamplesRead = frame.samplesRead;
      for (int ch = 0; ch < frame.channelCount && ch < _channels.length; ch++) {
        _bridgeFftMags[_channels[ch]] = frame.channelMags(ch);
      }
    });
  }

  void _onBridgeWaveFrame(DaqWaveFrame frame) {
    if (!_isRunning || !mounted) return;
    setState(() {
      _bridgeWaveSampleRateHz = frame.sampleRateHz;
      _bridgeWaveDecimStep = frame.decimStep;
      for (int ch = 0; ch < frame.channelCount && ch < _channels.length; ch++) {
        _bridgeWaveSamples[_channels[ch]] = frame.channelSamples[ch];
      }
    });
  }

  void _onAcquisitionSample(AcquisitionSample sample) {
    if (!_isRunning || !mounted) {
      return;
    }

    setState(() {
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
    final List<FlSpot> source = _history[channel]!;
    if (source.isEmpty) {
      return <FlSpot>[FlSpot(0, _chartMinG), FlSpot(1, _chartMinG)];
    }

    final DateTime now = DateTime.fromMillisecondsSinceEpoch(
      frameNowMs.toInt(),
    );
    List<FlSpot> visible = source;
    double baseMs;
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
      baseMs = realtimeCutoffMs;
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
      baseMs = windowCutoffMs;
    } else {
      baseMs = visible.first.x;
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

  String _formatRelativeTimeLabel(double seconds) {
    final int totalSeconds = seconds.round().clamp(0, 86400);
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int secs = totalSeconds % 60;

    if (hours > 0) {
      return '${hours}h${minutes.toString().padLeft(2, '0')}';
    }
    if (minutes > 0) {
      return '${minutes}m';
    }
    return '${secs}s';
  }

  double _combinedXAxisIntervalSeconds(double maxVisibleX) {
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
        return max(maxVisibleX / 5, 1);
      default:
        return max(maxVisibleX / 4, 1);
    }
  }

  Widget _buildCombinedBottomTitle(
    double value,
    TitleMeta meta,
    double maxVisibleX,
  ) {
    const TextStyle style = TextStyle(
      fontSize: 10,
      color: Color(0xFF5E6A79),
      fontWeight: FontWeight.w600,
    );

    final bool isStart = (value - meta.min).abs() < 0.5;
    final bool isEnd = (value - maxVisibleX).abs() < 0.5;
    String label = '';

    if (isStart) {
      if (_selectedCombinedWindowMinutes == -1) {
        label = '-${_combinedRealtimeSeconds}s';
      } else {
        label = _selectedCombinedWindowMinutes == 0
            ? 'Bắt đầu'
            : '-${_selectedCombinedWindowMinutes}m';
      }
    } else if (isEnd) {
      label = _selectedCombinedWindowMinutes == -1 ? 'Live' : 'Hiện tại';
    } else {
      final double remaining = (maxVisibleX - value).clamp(0, maxVisibleX);
      label = '-${_formatRelativeTimeLabel(remaining)}';
    }

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
    final int warningCount = _lastStates.values
        .where((s) => s == SensorState.warning)
        .length;
    final int dangerCount = _lastStates.values
        .where((s) => s == SensorState.danger)
        .length;
    final int normalCount = _lastStates.length - warningCount - dangerCount;
    final double maxSignal = _latestValues.values.isEmpty
        ? 0
        : _latestValues.values.reduce(max);
    final double ai9RawRms = _latestRawRmsVolts['AI9'] ?? 0;
    final String screenTitle = switch (_selectedScreenIndex) {
      0 => 'Cảnh báo bắn mìn - Địa vật lý Giếng Khoang',
      1 => 'Combined Channels',
      2 => 'System Panels',
      _ => 'Settings',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(screenTitle),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: FilledButton.tonalIcon(
              onPressed: _toggleConnection,
              icon: Icon(_isConnected ? Icons.link : Icons.link_off),
              label: Text(
                _useBridge
                    ? (_isConnected
                          ? 'Bridge Connected'
                          : 'Bridge Disconnected')
                    : (_isConnected ? 'Mock Connected' : 'Mock Disconnected'),
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (_selectedScreenIndex == 0) {
            return _buildMonitoringScreen(constraints);
          }

          if (_selectedScreenIndex == 1) {
            return _buildCombinedChartScreen(constraints);
          }

          if (_selectedScreenIndex == 2) {
            return _buildPanelsScreen(
              constraints,
              normalCount,
              warningCount,
              dangerCount,
              maxSignal,
              ai9RawRms,
            );
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
            icon: Icon(Icons.show_chart),
            label: 'Channels',
          ),
          NavigationDestination(
            icon: Icon(Icons.multiline_chart),
            label: 'Combined',
          ),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Panels'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
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

  Widget _buildPanelsScreen(
    BoxConstraints constraints,
    int normalCount,
    int warningCount,
    int dangerCount,
    double maxSignal,
    double ai9RawRms,
  ) {
    final bool isWide = constraints.maxWidth >= 1120;

    final Widget leftColumn = ListView(
      children: <Widget>[
        _buildControlPanel(),
        const SizedBox(height: 12),
        _buildVoltageRangePanel(),
        const SizedBox(height: 12),
        _buildSummaryPanel(
          normalCount,
          warningCount,
          dangerCount,
          maxSignal,
          ai9RawRms,
        ),
      ],
    );

    final Widget rightColumn = Column(
      children: <Widget>[
        _buildPipelinePanel(),
        const SizedBox(height: 12),
        Expanded(child: _buildEventPanel()),
      ],
    );

    if (isWide) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(flex: 3, child: leftColumn),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: rightColumn),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: <Widget>[
          _buildControlPanel(),
          const SizedBox(height: 12),
          _buildSummaryPanel(
            normalCount,
            warningCount,
            dangerCount,
            maxSignal,
            ai9RawRms,
          ),
          const SizedBox(height: 12),
          _buildPipelinePanel(),
          const SizedBox(height: 12),
          SizedBox(height: 360, child: _buildEventPanel()),
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
    final List<FlSpot> pts = _history[channel] ?? <FlSpot>[];
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

  Widget _buildFftPanel() {
    // ── Prefer real FFT from bridge; fall back to Dart-computed FFT (mock) ──
    final bool hasFrameFft =
        _bridgeFftBinCount > 1 && _bridgeFftMags.containsKey(_fftChannel);

    List<double> freqs;
    List<double> mags;
    double srHz;
    int samplesUsed;
    String sourceLabel;

    if (hasFrameFft) {
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
          ? 'Bridge FFT (hardware)'
          : 'Mock FFT (10kHz block simulation)';
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
      sourceLabel = 'Dart FFT (mock / RMS envelope)';
    }

    final double peakMag = mags.isEmpty ? 0.0 : mags.reduce(max);
    final double minMag = mags.isEmpty ? 0.0 : mags.reduce(min);
    final double safeMaxY = peakMag > 0 ? peakMag * 1.2 : 0.01;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildSamplingInfoCard(),
        const SizedBox(height: 8),
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
                'DBG FFT ${hasFrameFft ? (_useBridge ? 'bridge' : 'mock-frame') : 'mock-fallback'}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2F3B4A),
                ),
              ),
              Text(
                'N=$samplesUsed',
                style: const TextStyle(fontSize: 11, color: Color(0xFF4B5B6B)),
              ),
              Text(
                'Bins=${mags.length}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF4B5B6B)),
              ),
              Text(
                'Fs=${srHz.toStringAsFixed(1)} Hz',
                style: const TextStyle(fontSize: 11, color: Color(0xFF4B5B6B)),
              ),
              Text(
                'Min=${minMag.toStringAsFixed(4)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF4B5B6B)),
              ),
              Text(
                'Max=${peakMag.toStringAsFixed(4)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF4B5B6B)),
              ),
            ],
          ),
        ),
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
                    minX: freqs.first,
                    maxX: freqs.last,
                    minY: 0,
                    maxY: safeMaxY,
                    clipData: FlClipData.all(),
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (List<LineBarSpot> spots) {
                          return spots.map((LineBarSpot s) {
                            return LineTooltipItem(
                              '${s.x.toStringAsFixed(3)} Hz\n${s.y.toStringAsFixed(4)}',
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
                          'Tần số (Hz)',
                          style: TextStyle(fontSize: 10),
                        ),
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            return Text(
                              value.toStringAsFixed(2),
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
                          freqs.length,
                          (int i) => FlSpot(freqs[i], mags[i]),
                        ),
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

  Widget _buildWavePanel() {
    final List<double>? bridgeSamples = _bridgeWaveSamples[_waveChannel];
    final bool hasFrameData =
        bridgeSamples != null &&
        bridgeSamples.isNotEmpty &&
        _bridgeWaveSampleRateHz > 0;

    final List<double> mockSamples = (_history[_waveChannel] ?? <FlSpot>[])
        .map((FlSpot spot) => spot.y)
        .toList();
    if (mockSamples.length > 240) {
      mockSamples.removeRange(0, mockSamples.length - 240);
    }
    final bool hasMockData = !_useBridge && mockSamples.length > 1;

    final bool hasData = hasFrameData || hasMockData;
    final List<double> activeSamples = hasFrameData
        ? bridgeSamples
        : mockSamples;
    final int outCount = activeSamples.length;
    final double timeStepMs = hasFrameData
        ? (_bridgeWaveDecimStep / _bridgeWaveSampleRateHz * 1000.0)
        : _sampleIntervalMs.toDouble();
    final double blockMs = hasData
        ? (outCount > 1 ? (outCount - 1) * timeStepMs : timeStepMs)
        : 100.0;
    final bool autoExpandWindowForMock = !hasFrameData;
    final double displayTimeWindowMs = autoExpandWindowForMock
        ? max(blockMs, _waveformTimeWindowMs)
        : (_waveformTimeWindowMs > 0 ? _waveformTimeWindowMs : blockMs);
    final bool waveInVoltage = _useBridge && hasFrameData;
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
        _buildSamplingInfoCard(),
        const SizedBox(height: 8),
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
                    setState(() => _waveformTimeWindowMs = parsed);
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
                    _waveformTimeWindowMs = blockMs;
                    _waveformTimeWindowController.text = blockMs
                        .toStringAsFixed(1);
                  });
                },
                icon: const Icon(Icons.auto_awesome, size: 14),
                label: const Text('Auto', style: TextStyle(fontSize: 11)),
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
        const SizedBox(height: 8),
        if (hasData)
          Text(
            'Oscilloscope (${hasFrameData ? 'bridge' : 'mock'})  |  N=$outCount  |  Fs: ${effectiveFsHz.toStringAsFixed(1)} Hz'
            '  |  Block: ${blockMs.toStringAsFixed(1)} ms'
            '  |  Window: ${displayTimeWindowMs.toStringAsFixed(1)} ms'
            '${hasFrameData ? '  |  Decim: ×$_bridgeWaveDecimStep' : ''}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF5E6A79)),
          ),
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
                'DBG WAVE ${waveInVoltage ? 'bridge' : 'mock'}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2F3B4A),
                ),
              ),
              Text(
                'N=$outCount',
                style: const TextStyle(fontSize: 11, color: Color(0xFF4B5B6B)),
              ),
              Text(
                'Fs=${effectiveFsHz.toStringAsFixed(1)} Hz',
                style: const TextStyle(fontSize: 11, color: Color(0xFF4B5B6B)),
              ),
              Text(
                'Min=${minSample.toStringAsFixed(4)} $valueUnit',
                style: const TextStyle(fontSize: 11, color: Color(0xFF4B5B6B)),
              ),
              Text(
                'Max=${maxSample.toStringAsFixed(4)} $valueUnit',
                style: const TextStyle(fontSize: 11, color: Color(0xFF4B5B6B)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: !hasData
              ? const Center(
                  child: Text(
                    'Chưa đủ dữ liệu sóng (mock cần >= 2 mẫu)',
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
    final double frameNowMs = DateTime.now().millisecondsSinceEpoch.toDouble();
    final double? fixedWindowSeconds = _combinedFixedWindowSeconds();
    double maxVisibleX = fixedWindowSeconds ?? 1;

    for (final String channel in visibleChannels) {
      final List<FlSpot> safeSpots = _visibleSpotsForCombinedChart(
        channel,
        _selectedCombinedWindowMinutes,
        frameNowMs,
      );
      if (fixedWindowSeconds == null) {
        maxVisibleX = max(maxVisibleX, safeSpots.last.x);
      }

      final Color color = _channelColor(channel);
      lineBars.add(
        LineChartBarData(
          spots: safeSpots,
          isCurved: false,
          preventCurveOverShooting: true,
          color: color,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }

    final double xInterval = _combinedXAxisIntervalSeconds(maxVisibleX);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Tab selector row
              Row(
                children: <Widget>[
                  Text(
                    'Combined Channels',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  SegmentedButton<int>(
                    segments: const <ButtonSegment<int>>[
                      ButtonSegment<int>(
                        value: 0,
                        icon: Icon(Icons.multiline_chart, size: 16),
                        label: Text('Biểu đồ'),
                      ),
                      ButtonSegment<int>(
                        value: 1,
                        icon: Icon(Icons.equalizer, size: 16),
                        label: Text('FFT'),
                      ),
                      ButtonSegment<int>(
                        value: 2,
                        icon: Icon(Icons.show_chart, size: 16),
                        label: Text('Sóng'),
                      ),
                    ],
                    selected: <int>{_combinedViewTab},
                    onSelectionChanged: (Set<int> sel) {
                      setState(() => _combinedViewTab = sel.first);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _combinedViewTab == 1
                    ? _buildFftPanel()
                    : _combinedViewTab == 2
                    ? _buildWavePanel()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _buildSamplingInfoCard(),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: _combinedWindowOptions.map((
                              _CombinedWindowOption option,
                            ) {
                              final bool selected =
                                  _selectedCombinedWindowMinutes ==
                                  option.minutes;
                              return ChoiceChip(
                                label: Text(option.label),
                                selected: selected,
                                onSelected: (_) {
                                  setState(() {
                                    _selectedCombinedWindowMinutes =
                                        option.minutes;
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: <Widget>[
                              Text(
                                'Hiển thị ${visibleChannels.length}/${_channels.length} kênh',
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
                                    _hiddenCombinedChannels.clear();
                                  });
                                },
                                child: const Text('Hiện tất cả'),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _hiddenCombinedChannels
                                      ..clear()
                                      ..addAll(_channels);
                                  });
                                },
                                child: const Text('Bỏ tất cả'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
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
                                      minX: 0,
                                      maxX: maxVisibleX,
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
                                            ).withValues(alpha: 0.5),
                                            strokeWidth: 1.6,
                                            dashArray: <int>[5, 5],
                                          ),
                                          HorizontalLine(
                                            y: _dangerThreshold,
                                            color: const Color(
                                              0xFFC0392B,
                                            ).withValues(alpha: 0.5),
                                            strokeWidth: 1.6,
                                            dashArray: <int>[5, 5],
                                          ),
                                        ],
                                      ),
                                      titlesData: FlTitlesData(
                                        leftTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        rightTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        topTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 22,
                                            interval: xInterval,
                                            getTitlesWidget:
                                                (double value, TitleMeta meta) {
                                                  return _buildCombinedBottomTitle(
                                                    value,
                                                    meta,
                                                    maxVisibleX,
                                                  );
                                                },
                                          ),
                                        ),
                                      ),
                                      borderData: FlBorderData(show: false),
                                      lineBarsData: lineBars,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F8FB),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              children: _channels.map((String channel) {
                                final Color color = _channelColor(channel);
                                final bool selected = _isCombinedChannelVisible(
                                  channel,
                                );
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

  Widget _buildSettingsScreen() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'DAQ Settings',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 12),
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
                          labelText: 'Min input value',
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
                          labelText: 'Max input value',
                          hintText: '10',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _sampleRateController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Sample rate (Hz)',
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
                          labelText: 'Samples per read',
                          hintText: '1000',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _applySamplingSettings,
                  icon: const Icon(Icons.speed),
                  label: const Text('Apply sampling'),
                ),
                const SizedBox(height: 10),
                Text(
                  'Current sampling: $_sampleRateHz Hz, $_samplesPerRead samples/read',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Accelerometer Preset (auto --accel-sens)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedAccelPresetId,
                        decoration: const InputDecoration(
                          labelText: 'Sensor preset',
                        ),
                        items: _accelPresets
                            .map(
                              (_AccelSensorPreset preset) =>
                                  DropdownMenuItem<String>(
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
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _applyAccelPresetAndSensitivity,
                      icon: const Icon(Icons.sensors),
                      label: const Text('Apply preset'),
                    ),
                  ],
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
                    labelText: 'Sensitivity (mV/g)',
                    hintText: '100',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Effective sensitivity: ${_effectiveAccelSensitivityMvPerG().toStringAsFixed(2)} mV/g',
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: DropdownButtonFormField<BridgeAiChannelMode>(
                        value: _aiChannelMode,
                        decoration: const InputDecoration(
                          labelText: 'AI channel mode',
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
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _applyAiChannelMode,
                      icon: const Icon(Icons.tune),
                      label: const Text('Apply mode'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Current AI function: ${_aiModeLabel(_aiChannelMode)}'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _applyVoltageRange,
                  icon: const Icon(Icons.save),
                  label: const Text('Apply range'),
                ),
                const SizedBox(height: 10),
                Text(
                  'Current range: ${_voltageMin.toStringAsFixed(2)} ${_bridgeRawUnitLabel()} .. ${_voltageMax.toStringAsFixed(2)} ${_bridgeRawUnitLabel()}',
                ),
                const SizedBox(height: 6),
                Text(
                  'Bridge args: $_bridgeArguments',
                  style: const TextStyle(fontSize: 12.5),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),
                const Text(
                  'Chart Scale (g)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 12),
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
                          labelText: 'Chart min (g)',
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
                          labelText: 'Chart max (g)',
                          hintText: '1.2',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _applyChartScale,
                  icon: const Icon(Icons.stacked_line_chart),
                  label: const Text('Apply chart scale'),
                ),
                const SizedBox(height: 10),
                Text(
                  'Current chart scale: ${_chartMinG.toStringAsFixed(2)} g .. ${_chartMaxG.toStringAsFixed(2)} g',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSamplingInfoCard() {
    final String actualSamplingLabel = _useBridge
        ? (_isConnected &&
                  _actualSampleRateHz != null &&
                  _actualSamplesPerRead != null
              ? 'Actual: ${_actualSampleRateHz!} Hz | ${_actualSamplesPerRead!} samples/read'
              : 'Actual: waiting for bridge data...')
        : 'Actual: mock source';

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.speed, size: 18, color: Color(0xFF005A9C)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Config: $_sampleRateHz Hz | $_samplesPerRead samples/read',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2F3B4A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              actualSamplingLabel,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF5E6A79),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Acquisition Control',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                Platform.isWindows
                    ? 'Use built-in NI-DAQ bridge (multi-channel)'
                    : 'Use external DAQ bridge (multi-channel)',
              ),
              subtitle: Text(
                Platform.isWindows
                    ? 'Optional. On Windows the app reads NI-DAQmx directly.'
                    : 'Optional. Keep off to run mock-only mode.',
              ),
              value: _useBridge,
              onChanged: (bool enabled) {
                unawaited(_toggleDataSource(enabled));
              },
            ),
            TextField(
              controller: _bridgePathController,
              enabled: !Platform.isWindows,
              decoration: InputDecoration(
                labelText: Platform.isWindows
                    ? 'Bridge executable path (not used on Windows)'
                    : 'Bridge executable path',
                hintText: Platform.isWindows
                    ? 'Windows uses the built-in NI-DAQ bridge'
                    : 'D:\\your-adapter\\daq_bridge.exe',
              ),
              onChanged: (String value) {
                _bridgeExecutablePath = value.trim();
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bridgeArgsController,
              decoration: const InputDecoration(
                labelText: 'Bridge arguments',
                hintText: '--stream --rate 10000 --samples 1000',
              ),
              onChanged: (String value) {
                setState(() {
                  _bridgeArguments = value;
                  _aiChannelMode = _extractAiModeFromArgs(value);
                });
                _syncAcquisitionSignalUnit();
              },
            ),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _toggleRun,
                  icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                  label: Text(_isRunning ? 'Pause stream' : 'Resume stream'),
                ),
                const SizedBox(width: 10),
                Text(_isRunning ? 'Running' : 'Paused'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _isConnected ? null : _connectConnection,
                  icon: const Icon(Icons.link),
                  label: const Text('Connect'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _isConnected
                      ? () async {
                          final bool shouldDisconnect =
                              await _confirmDisconnectConnection();
                          if (!shouldDisconnect) {
                            return;
                          }
                          await _disconnectConnection(
                            reason: 'control panel button',
                          );
                        }
                      : null,
                  icon: const Icon(Icons.link_off),
                  label: const Text('Disconnect'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Icon(
                  Icons.circle,
                  size: 12,
                  color: _isConnected
                      ? const Color(0xFF2E8B57)
                      : const Color(0xFFC0392B),
                ),
                const SizedBox(width: 6),
                Text(
                  _isConnected
                      ? (_useBridge ? 'Bridge connected' : 'Mock connected')
                      : (_useBridge
                            ? 'Bridge disconnected'
                            : 'Mock disconnected'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _useBridge
                  ? 'Bridge config: ${_bridgeExecutablePath.isEmpty ? '<not set>' : _bridgeExecutablePath} | args: $_bridgeArguments'
                  : 'Sampling interval: $_sampleIntervalMs ms',
            ),
            if (!_useBridge)
              Slider(
                min: 100,
                max: 1200,
                divisions: 11,
                value: _sampleIntervalMs.toDouble(),
                label: '$_sampleIntervalMs ms',
                onChanged: (double value) {
                  setState(() {
                    _sampleIntervalMs = value.toInt();
                    _startAcquisition();
                  });
                },
              ),
            if (_lastAutoFallbackAt != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE4A100)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFE4A100),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Auto fallback at ${_lastAutoFallbackAt!.toLocal()}: switched to voltage mode. $_lastAutoFallbackReason',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6D4C1A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _resetAutoFallbackStatus,
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('Reset fallback status'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
          ],
        ),
      ),
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

  Widget _buildSummaryPanel(
    int normalCount,
    int warningCount,
    int dangerCount,
    double maxSignal,
    double ai9RawRms,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _summaryTile(
              _stateLabel(SensorState.normal),
              normalCount.toString(),
              const Color(0xFF2E8B57),
            ),
            _summaryTile(
              _stateLabel(SensorState.warning),
              warningCount.toString(),
              const Color(0xFFE4A100),
            ),
            _summaryTile(
              _stateLabel(SensorState.danger),
              dangerCount.toString(),
              const Color(0xFFC0392B),
            ),
            _summaryTile(
              'Peak signal',
              '${maxSignal.toStringAsFixed(3)} g',
              const Color(0xFF005A9C),
            ),
            _summaryTile(
              'AI9 raw RMS',
              '${ai9RawRms.toStringAsFixed(4)} ${_bridgeRawUnitLabel()}',
              const Color(0xFF4A6FA5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoltageRangePanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'DAQ Input Range',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                _rangeValueTile(
                  _aiChannelMode == BridgeAiChannelMode.accel
                      ? 'Min g'
                      : 'Min V',
                  '${_voltageMin.toStringAsFixed(2)} ${_bridgeRawUnitLabel()}',
                  const Color(0xFF2E8B57),
                ),
                _rangeValueTile(
                  _aiChannelMode == BridgeAiChannelMode.accel
                      ? 'Max g'
                      : 'Max V',
                  '${_voltageMax.toStringAsFixed(2)} ${_bridgeRawUnitLabel()}',
                  const Color(0xFF005A9C),
                ),
                _rangeValueTile(
                  'Range',
                  '${(_voltageMax - _voltageMin).toStringAsFixed(2)} ${_bridgeRawUnitLabel()}',
                  const Color(0xFFE4A100),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _rangeValueTile(String label, String value, Color color) {
    return Column(
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _summaryTile(String label, String value, Color color) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
        ],
      ),
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

  Widget _buildPipelinePanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const <Widget>[
            Text(
              'System Pipeline',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            SizedBox(height: 10),
            Text('C Series Sensor Module -> cDAQ Chassis -> NI-DAQmx C API'),
            SizedBox(height: 4),
            Text('External DAQ adapter process -> Flutter stdout parser'),
            SizedBox(height: 4),
            Text(
              'Reference folder cdaq-9181-console is optional guidance only.',
            ),
            Text(
              'Expected line protocol: DATA_MULTI,<rate>,<samplesRead>,<channelCount>,<rms0>...<rmsN>',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Event Log',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _eventLogs.isEmpty
                  ? const Center(child: Text('No events yet'))
                  : ListView.separated(
                      itemCount: _eventLogs.length,
                      separatorBuilder: (_, __) => const Divider(height: 8),
                      itemBuilder: (BuildContext context, int index) {
                        return Text(
                          _eventLogs[index],
                          style: const TextStyle(fontSize: 12.5),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
