import 'dart:async';
import 'dart:math';

import 'daq_bridge_client.dart';

enum AcquisitionSource { mock, bridge }

enum BridgeSignalUnit { voltage, accelerationG }

class AcquisitionSample {
  AcquisitionSample({
    required this.values,
    this.rawRmsVolts = const <String, double>{},
    this.sampleRateHz,
    this.samplesRead,
  });

  final Map<String, double> values;
  final Map<String, double> rawRmsVolts;
  final int? sampleRateHz;
  final int? samplesRead;
}

class DataAcquisitionService {
  DataAcquisitionService({required List<String> channels})
    : _channels = List<String>.from(channels) {
    _bridgeFrameSub = _bridgeClient.frames.listen(_onBridgeFrame);
    _bridgeFftSub = _bridgeClient.fftFrames.listen((DaqFftFrame frame) {
      if (!_fftController.isClosed) {
        _fftController.add(frame);
      }
    });
    _bridgeWaveSub = _bridgeClient.waveFrames.listen((DaqWaveFrame frame) {
      if (!_waveController.isClosed) {
        _waveController.add(frame);
      }
    });
    _bridgeStatusSub = _bridgeClient.status.listen((String line) {
      _statusController.add(line);
    });
  }

  final List<String> _channels;
  final Random _random = Random();
  final DaqBridgeClient _bridgeClient = DaqBridgeClient();

  final StreamController<AcquisitionSample> _sampleController =
      StreamController<AcquisitionSample>.broadcast();
  final StreamController<DaqFftFrame> _fftController =
      StreamController<DaqFftFrame>.broadcast();
  final StreamController<DaqWaveFrame> _waveController =
      StreamController<DaqWaveFrame>.broadcast();
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  StreamSubscription<DaqFrame>? _bridgeFrameSub;
  StreamSubscription<DaqFftFrame>? _bridgeFftSub;
  StreamSubscription<DaqWaveFrame>? _bridgeWaveSub;
  StreamSubscription<String>? _bridgeStatusSub;
  Timer? _mockTimer;

  AcquisitionSource _source = AcquisitionSource.mock;
  BridgeSignalUnit _bridgeSignalUnit = BridgeSignalUnit.voltage;
  bool _isRunning = true;
  bool _isMockConnected = true;
  int _mockSampleRateHz = 10000;
  int _mockSamplesPerRead = 1000;
  int _mockSampleCursor = 0;

  Stream<AcquisitionSample> get samples => _sampleController.stream;
  Stream<String> get status => _statusController.stream;

  /// FFT frames from active source (bridge or mock simulation).
  Stream<DaqFftFrame> get fftFrames => _fftController.stream;

  /// Waveform frames from active source (bridge or mock simulation).
  Stream<DaqWaveFrame> get waveFrames => _waveController.stream;

  bool get isBridgeRunning => _bridgeClient.isRunning;
  bool get isMockConnected => _isMockConnected;

  void setRunning(bool value) {
    _isRunning = value;
  }

  void setSource(AcquisitionSource source) {
    _source = source;
  }

  void setBridgeSignalUnit(BridgeSignalUnit unit) {
    _bridgeSignalUnit = unit;
  }

  void setMockConnected(bool connected) {
    _isMockConnected = connected;
  }

  void setMockSamplingConfig({
    required int sampleRateHz,
    required int samplesPerRead,
  }) {
    if (sampleRateHz > 0) {
      _mockSampleRateHz = sampleRateHz;
    }
    if (samplesPerRead > 0) {
      _mockSamplesPerRead = samplesPerRead;
    }
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
    _bridgeFftSub?.cancel();
    _bridgeWaveSub?.cancel();
    _bridgeStatusSub?.cancel();
    await _bridgeClient.dispose();
    await _sampleController.close();
    await _fftController.close();
    await _waveController.close();
    await _statusController.close();
  }

  void _emitMockSample() {
    if (_source != AcquisitionSource.mock || !_isRunning || !_isMockConnected) {
      return;
    }

    final int sampleRateHz = _mockSampleRateHz;
    final int samplesPerRead = _mockSamplesPerRead;
    final int fftSize = DaqFftFrame.nextPow2(samplesPerRead);
    final int decimStep = max(1, samplesPerRead ~/ 200);
    final double blockStartSec = _mockSampleCursor / sampleRateHz;

    final Map<String, double> values = <String, double>{};
    final Map<String, double> rawRmsVolts = <String, double>{};
    final List<List<double>> waveChannelSamples = List<List<double>>.generate(
      _channels.length,
      (_) => <double>[],
    );
    final List<double> flatFftMagnitudes = <double>[];

    for (int i = 0; i < _channels.length; i++) {
      final String channel = _channels[i];
      final double lowFreqHz = 110.0 + i * 8.0;
      final double midFreqHz = 280.0 + i * 14.0;
      final double amp1 = 0.30 + (i % 4) * 0.02;
      final double amp2 = 0.18 + (i % 3) * 0.015;
      final double phase = i * 0.4;
      final double env1 =
          1.0 + 0.55 * sin(2 * pi * (0.65 + i * 0.02) * blockStartSec + phase);
      final double env2 =
          1.0 + 0.45 * sin(2 * pi * (1.15 + i * 0.015) * blockStartSec + phase * 0.8);

      final List<double> channelBlock = List<double>.filled(
        samplesPerRead,
        0.0,
      );
      double sumSq = 0.0;

      for (int n = 0; n < samplesPerRead; n++) {
        final double t = (_mockSampleCursor + n) / sampleRateHz;
        final double noise = (_random.nextDouble() - 0.5) * 0.09;
        final bool hasImpulse = _random.nextDouble() < 0.0018;
        final double impulse = hasImpulse
          ? ((_random.nextDouble() - 0.5) * 0.7)
            : 0.0;
        final double drift = 0.08 * sin(2 * pi * 0.22 * t + phase * 0.35);
        final double sample =
          0.40 +
          (amp1 * env1) * sin(2 * pi * lowFreqHz * t + phase) +
          (amp2 * env2) * sin(2 * pi * midFreqHz * t + phase * 0.7) +
          drift +
            noise +
            impulse;
        final double clamped = sample.clamp(0.0, 1.2).toDouble();
        channelBlock[n] = clamped;
        sumSq += clamped * clamped;
      }

      final double rms = sqrt(sumSq / samplesPerRead);
      values[channel] = rms;
      rawRmsVolts[channel] = rms;

      final List<double> decimated = <double>[];
      for (int n = 0; n < samplesPerRead; n += decimStep) {
        decimated.add(channelBlock[n]);
      }
      waveChannelSamples[i] = decimated;

      final List<double> padded = List<double>.filled(fftSize, 0.0);
      for (int n = 0; n < samplesPerRead; n++) {
        padded[n] = channelBlock[n];
      }
      final List<double> mags = _fftMagnitudes(padded);
      flatFftMagnitudes.addAll(mags);
    }

    _mockSampleCursor += samplesPerRead;

    _sampleController.add(
      AcquisitionSample(
        values: values,
        rawRmsVolts: rawRmsVolts,
        sampleRateHz: sampleRateHz,
        samplesRead: samplesPerRead,
      ),
    );

    if (!_waveController.isClosed) {
      _waveController.add(
        DaqWaveFrame(
          sampleRateHz: sampleRateHz,
          samplesRead: samplesPerRead,
          decimStep: decimStep,
          channelCount: _channels.length,
          channelSamples: waveChannelSamples,
        ),
      );
    }

    if (!_fftController.isClosed) {
      _fftController.add(
        DaqFftFrame(
          sampleRateHz: sampleRateHz,
          samplesRead: samplesPerRead,
          channelCount: _channels.length,
          binCount: fftSize ~/ 2,
          magnitudes: flatFftMagnitudes,
        ),
      );
    }
  }

  List<double> _fftMagnitudes(List<double> input) {
    final int n = input.length;
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
        final double tmpRe = re[i];
        re[i] = re[j];
        re[j] = tmpRe;
        final double tmpIm = im[i];
        im[i] = im[j];
        im[j] = tmpIm;
      }
    }

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
      values[channel] = _bridgeSignalUnit == BridgeSignalUnit.accelerationG
          ? rms
          : (rms / 2.0).clamp(0.0, 1.2);
    }

    final double ai9Rms = rmsValues.length > 9 ? rmsValues[9] : 0.0;
    final String unitLabel = _bridgeSignalUnit == BridgeSignalUnit.accelerationG
        ? 'g'
        : 'V';

    _statusController.add(
      'DATA ${frame.sampleRateHz} Hz, block ${frame.samplesRead}, channels ${rmsValues.length}, AI9 rms ${ai9Rms.toStringAsFixed(4)} $unitLabel',
    );
    _sampleController.add(
      AcquisitionSample(
        values: values,
        rawRmsVolts: rawRmsVolts,
        sampleRateHz: frame.sampleRateHz,
        samplesRead: frame.samplesRead,
      ),
    );
  }
}
