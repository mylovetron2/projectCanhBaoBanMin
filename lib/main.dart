import 'dart:async';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  int _selectedScreenIndex = 0;
  int _selectedCombinedWindowMinutes = 15;
  final Set<String> _hiddenCombinedChannels = <String>{};
  double _warningThreshold = 0.65;
  double _dangerThreshold = 0.85;
  int _sampleIntervalMs = 500;
  double _voltageMin = -10.0;
  double _voltageMax = 10.0;
  double _chartMinG = 0.0;
  double _chartMaxG = 1.2;

  String _bridgeExecutablePath =
      'd:\\projectSumome\\cdaq-9181-console\\build\\cdaq9181_console.exe';
  String _bridgeArguments =
      '--stream --rate 10000 --samples 1000 --min -10 --max 10 cDAQ9181-1E439C1Mod1/ai0:15';
  late final TextEditingController _bridgePathController;
  late final TextEditingController _bridgeArgsController;
  late final TextEditingController _voltageMinController;
  late final TextEditingController _voltageMaxController;
  late final TextEditingController _chartMinController;
  late final TextEditingController _chartMaxController;

  static const Duration _historyRetention = Duration(hours: 4);
  static const List<_CombinedWindowOption> _combinedWindowOptions =
      <_CombinedWindowOption>[
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
    _chartMinController = TextEditingController(text: _chartMinG.toString());
    _chartMaxController = TextEditingController(text: _chartMaxG.toString());
    _acquisitionService = DataAcquisitionService(channels: _channels);

    for (final String channel in _channels) {
      _history[channel] = <FlSpot>[];
      _latestValues[channel] = 0;
      _latestRawRmsVolts[channel] = 0;
      _lastStates[channel] = SensorState.normal;
    }

    _sampleSub = _acquisitionService.samples.listen(_onAcquisitionSample);
    _statusSub = _acquisitionService.status.listen((String line) {
      if (!mounted) {
        return;
      }
      setState(() {
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
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sampleSub?.cancel();
    _statusSub?.cancel();
    _syncSettingsFromInputs();
    unawaited(_saveSettings());
    _bridgePathController.dispose();
    _bridgeArgsController.dispose();
    _voltageMinController.dispose();
    _voltageMaxController.dispose();
    _chartMinController.dispose();
    _chartMaxController.dispose();
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

  Future<void> _loadSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? savedPath = prefs.getString(_prefBridgePath);
    final String? savedArgs = prefs.getString(_prefBridgeArgs);
    final double? savedMin = prefs.getDouble(_prefVoltageMin);
    final double? savedMax = prefs.getDouble(_prefVoltageMax);
    final bool? savedUseBridge = prefs.getBool(_prefUseBridge);
    final double? savedChartMin = prefs.getDouble(_prefChartMinG);
    final double? savedChartMax = prefs.getDouble(_prefChartMaxG);

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

      _bridgePathController.text = _bridgeExecutablePath;
      _bridgeArgsController.text = _bridgeArguments;
      _voltageMinController.text = _voltageMin.toString();
      _voltageMaxController.text = _voltageMax.toString();
      _chartMinController.text = _chartMinG.toString();
      _chartMaxController.text = _chartMaxG.toString();
    });
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
        '[${DateTime.now().toLocal()}] Voltage range updated to ${minValue.toStringAsFixed(2)} V .. ${maxValue.toStringAsFixed(2)} V',
      );
      _trimLogs();
    });
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
    _acquisitionService.startMock(intervalMs: _sampleIntervalMs);
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
      if (_bridgeExecutablePath.trim().isEmpty) {
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
        args: _splitArguments(_bridgeArguments),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isConnected = true;
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

      _isConnected = _useBridge
          ? _acquisitionService.isBridgeRunning
          : _isConnected;
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
  ) {
    final List<FlSpot> source = _history[channel]!;
    if (source.isEmpty) {
      return <FlSpot>[const FlSpot(0, 0), const FlSpot(1, 0)];
    }

    List<FlSpot> visible = source;
    if (selectedWindowMinutes > 0) {
      final double cutoffMs = DateTime.now()
          .subtract(Duration(minutes: selectedWindowMinutes))
          .millisecondsSinceEpoch
          .toDouble();
      visible = source.where((FlSpot spot) => spot.x >= cutoffMs).toList();
      if (visible.isEmpty) {
        visible = <FlSpot>[source.last];
      }
    }

    final double baseMs = visible.first.x;
    final List<FlSpot> rebased = visible
        .map((FlSpot spot) => FlSpot((spot.x - baseMs) / 1000, spot.y))
        .toList();

    if (rebased.length == 1) {
      final FlSpot only = rebased.first;
      return <FlSpot>[only, FlSpot(only.x + 1, only.y)];
    }

    return rebased;
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
      label = _selectedCombinedWindowMinutes == 0
          ? 'Bắt đầu'
          : '-${_selectedCombinedWindowMinutes}m';
    } else if (isEnd) {
      label = 'Hiện tại';
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
    final double sensorPanelHeight = max(360, constraints.maxHeight - 32);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(height: sensorPanelHeight, child: _buildSensorGrid()),
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

  Widget _buildCombinedChartScreen(BoxConstraints constraints) {
    final double chartRange = _chartMaxG - _chartMinG;
    final List<LineChartBarData> lineBars = <LineChartBarData>[];
    final List<String> visibleChannels = _channels
        .where(_isCombinedChannelVisible)
        .toList();
    double maxVisibleX = 1;

    for (final String channel in visibleChannels) {
      final List<FlSpot> safeSpots = _visibleSpotsForCombinedChart(
        channel,
        _selectedCombinedWindowMinutes,
      );
      maxVisibleX = max(maxVisibleX, safeSpots.last.x);

      final Color color = _channelColor(channel);
      lineBars.add(
        LineChartBarData(
          spots: safeSpots,
          isCurved: true,
          curveSmoothness: 0.2,
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
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Biểu đồ tổng hợp 16 kênh',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _combinedWindowOptions.map((
                  _CombinedWindowOption option,
                ) {
                  final bool selected =
                      _selectedCombinedWindowMinutes == option.minutes;
                  return ChoiceChip(
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
                        LineChartData(
                          minX: 0,
                          maxX: maxVisibleX,
                          minY: _chartMinG,
                          maxY: _chartMaxG,
                          lineTouchData: const LineTouchData(enabled: false),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: max(chartRange / 6, 0.05),
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
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F8FB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: _channels.map((String channel) {
                    final Color color = _channelColor(channel);
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
                          labelText: 'Min voltage',
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
                          labelText: 'Max voltage',
                          hintText: '10',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _applyVoltageRange,
                  icon: const Icon(Icons.save),
                  label: const Text('Apply range'),
                ),
                const SizedBox(height: 10),
                Text(
                  'Current range: ${_voltageMin.toStringAsFixed(2)} V .. ${_voltageMax.toStringAsFixed(2)} V',
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
              title: const Text('Use external DAQ bridge (multi-channel)'),
              subtitle: const Text('Optional. Keep off to run mock-only mode.'),
              value: _useBridge,
              onChanged: (bool enabled) {
                unawaited(_toggleDataSource(enabled));
              },
            ),
            TextField(
              controller: _bridgePathController,
              decoration: const InputDecoration(
                labelText: 'Bridge executable path',
                hintText: 'D:\\your-adapter\\daq_bridge.exe',
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
                _bridgeArguments = value;
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
                    title: 'Ngưỡng nguy hiểm',
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
              '${ai9RawRms.toStringAsFixed(4)} V',
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
                  'Min',
                  '${_voltageMin.toStringAsFixed(2)} V',
                  const Color(0xFF2E8B57),
                ),
                _rangeValueTile(
                  'Max',
                  '${_voltageMax.toStringAsFixed(2)} V',
                  const Color(0xFF005A9C),
                ),
                _rangeValueTile(
                  'Range',
                  '${(_voltageMax - _voltageMin).toStringAsFixed(2)} V',
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

  Widget _buildSensorGrid() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: GridView.builder(
          itemCount: _channels.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            mainAxisExtent: 260,
          ),
          itemBuilder: (BuildContext context, int index) {
            final String channel = _channels[index];
            final double value = _latestValues[channel] ?? 0;
            final double rawRmsVolts = _latestRawRmsVolts[channel] ?? 0;
            final SensorState state =
                _lastStates[channel] ?? SensorState.normal;
            final Color color = _stateColor(state);
            final double chartRange = _chartMaxG - _chartMinG;
            final List<FlSpot> channelSpots = _history[channel]!;
            final List<FlSpot> safeSpots;
            if (channelSpots.isEmpty) {
              safeSpots = <FlSpot>[const FlSpot(0, 0), const FlSpot(1, 0)];
            } else if (channelSpots.length == 1) {
              final FlSpot only = channelSpots.first;
              safeSpots = <FlSpot>[only, FlSpot(only.x + 1, only.y)];
            } else {
              safeSpots = channelSpots;
            }

            return Container(
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
                    'RMS ${rawRmsVolts.toStringAsFixed(4)} V',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  Text(
                    'Range: ${_voltageMin.toStringAsFixed(1)} to ${_voltageMax.toStringAsFixed(1)} V',
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
                                LineChartData(
                                  minY: _chartMinG,
                                  maxY: _chartMaxG,
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
                                      isCurved: true,
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
