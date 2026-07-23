import 'dart:async';
import 'dart:math';

import 'daq_bridge_client.dart';

enum AcquisitionSource { mock, bridge }

class AcquisitionSample {
  AcquisitionSample({
    required this.values,
    this.rawRmsVolts = const <String, double>{},
  });

  final Map<String, double> values;
  final Map<String, double> rawRmsVolts;
}

class DataAcquisitionService {
  DataAcquisitionService({required List<String> channels})
    : _channels = List<String>.from(channels) {
    _bridgeFrameSub = _bridgeClient.frames.listen(_onBridgeFrame);
    _bridgeStatusSub = _bridgeClient.status.listen((String line) {
      _statusController.add(line);
    });
  }

  final List<String> _channels;
  final Random _random = Random();
  final DaqBridgeClient _bridgeClient = DaqBridgeClient();

  final StreamController<AcquisitionSample> _sampleController =
      StreamController<AcquisitionSample>.broadcast();
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  StreamSubscription<DaqFrame>? _bridgeFrameSub;
  StreamSubscription<String>? _bridgeStatusSub;
  Timer? _mockTimer;

  AcquisitionSource _source = AcquisitionSource.mock;
  bool _isRunning = true;
  bool _isMockConnected = true;
  double _tick = 0;

  Stream<AcquisitionSample> get samples => _sampleController.stream;
  Stream<String> get status => _statusController.stream;

  bool get isBridgeRunning => _bridgeClient.isRunning;

  void setRunning(bool value) {
    _isRunning = value;
  }

  void setSource(AcquisitionSource source) {
    _source = source;
  }

  void setMockConnected(bool connected) {
    _isMockConnected = connected;
  }

  void startMock({required int intervalMs}) {
    _mockTimer?.cancel();
    _mockTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) => _emitMockSample(),
    );
  }

  Future<void> startBridge({
    required String executablePath,
    required List<String> args,
  }) async {
    await _bridgeClient.start(executablePath: executablePath, args: args);
  }

  Future<void> stopBridge() async {
    await _bridgeClient.stop();
  }

  Future<void> dispose() async {
    _mockTimer?.cancel();
    _bridgeFrameSub?.cancel();
    _bridgeStatusSub?.cancel();
    await _bridgeClient.dispose();
    await _sampleController.close();
    await _statusController.close();
  }

  void _emitMockSample() {
    if (_source != AcquisitionSource.mock || !_isRunning || !_isMockConnected) {
      return;
    }

    _tick += 1;
    final Map<String, double> values = <String, double>{};

    for (int i = 0; i < _channels.length; i++) {
      final String channel = _channels[i];
      final double baseWave = 0.45 + 0.24 * sin((_tick / 9) + (i * 0.65));
      final double noise = _random.nextDouble() * 0.16;
      final bool hasSpike = _random.nextDouble() < 0.025;
      final double spike = hasSpike ? (0.25 + _random.nextDouble() * 0.35) : 0;
      final double value = (baseWave + noise + spike).clamp(0.0, 1.2);
      values[channel] = value;
    }

    _sampleController.add(AcquisitionSample(values: values));
  }

  void _onBridgeFrame(DaqFrame frame) {
    if (_source != AcquisitionSource.bridge || !_isRunning) {
      return;
    }

    final Map<String, double> values = <String, double>{};
    final Map<String, double> rawRmsVolts = <String, double>{};
    final List<double> rmsValues = frame.channelRmsVolts;

    for (int i = 0; i < _channels.length; i++) {
      final String channel = _channels[i];
      final double rms = i < rmsValues.length ? rmsValues[i] : 0.0;
      rawRmsVolts[channel] = rms;
      values[channel] = (rms / 2.0).clamp(0.0, 1.2);
    }

    final double ai9Rms = rmsValues.length > 9 ? rmsValues[9] : 0.0;

    _statusController.add(
      'DATA ${frame.sampleRateHz} Hz, block ${frame.samplesRead}, channels ${rmsValues.length}, AI9 rms ${ai9Rms.toStringAsFixed(4)} V',
    );
    _sampleController.add(
      AcquisitionSample(values: values, rawRmsVolts: rawRmsVolts),
    );
  }
}
