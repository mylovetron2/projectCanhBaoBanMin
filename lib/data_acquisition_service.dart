import 'dart:async';

import 'daq_bridge_client.dart';

enum BridgeSignalUnit { voltage, accelerationG }

class AcquisitionSample {
  AcquisitionSample({
    required this.values,
    this.rawRmsVolts = const <String, double>{},
    this.sampleRateHz,
    this.samplesRead,
    this.fftFrame,
    this.waveFrame,
  });

  final Map<String, double> values;
  final Map<String, double> rawRmsVolts;
  final int? sampleRateHz;
  final int? samplesRead;
  final DaqFftFrame? fftFrame;
  final DaqWaveFrame? waveFrame;
}

/// Orchestrates the NI-DAQmx bridge process and exposes a single unified
/// stream of [AcquisitionSample] to the UI layer. The UI never talks to
/// [DaqBridgeClient] or `Process` directly; this keeps the acquisition layer
/// fully independent from the display layer.
class DataAcquisitionService {
  DataAcquisitionService({required List<String> channels})
    : _channels = List<String>.from(channels) {
    _bridgeBlockSub = _bridgeClient.blockFrames.listen(_onBridgeBlockFrame);
    _bridgeFrameSub = _bridgeClient.frames.listen(_onBridgeFrame);
    _bridgeFftSub = _bridgeClient.fftFrames.listen((DaqFftFrame frame) {
      // Bridge sends DATA_MULTI, FFT_MULTI and WAVE_MULTI as separate lines
      // for the same block. Cache the latest FFT frame here so it can be
      // attached to the AcquisitionSample built from DATA_MULTI below;
      // otherwise the UI (which only listens to `samples`) never receives
      // FFT data and the FFT panel stays empty.
      _lastFftFrame = frame;
      if (!_fftController.isClosed) {
        _fftController.add(frame);
      }
    });
    _bridgeWaveSub = _bridgeClient.waveFrames.listen((DaqWaveFrame frame) {
      // See comment above: cache latest waveform frame for the same reason.
      _lastWaveFrame = frame;
      if (!_waveController.isClosed) {
        _waveController.add(frame);
      }
    });
    _bridgeStatusSub = _bridgeClient.status.listen((String line) {
      _statusController.add(line);
    });
  }

  final List<String> _channels;
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
  StreamSubscription<DaqBlockFrame>? _bridgeBlockSub;
  StreamSubscription<String>? _bridgeStatusSub;

  // Latest FFT/waveform frames received via the standalone FFT_MULTI /
  // WAVE_MULTI protocol lines (used by the current bridge, which does not
  // emit combined BLOCK_MULTI lines). Cached so they can be attached to the
  // AcquisitionSample built from the DATA_MULTI (RMS) frame.
  DaqFftFrame? _lastFftFrame;
  DaqWaveFrame? _lastWaveFrame;

  BridgeSignalUnit _bridgeSignalUnit = BridgeSignalUnit.voltage;

  // Acquisition keeps running (process + stream parsing) even when
  // `_isRunning` is false; this flag only gates whether parsed samples are
  // forwarded to the UI. This is intentional: pausing the app in the UI
  // must never stop or restart the underlying bridge process, and losing
  // window focus / minimizing must never affect acquisition either.
  bool _isRunning = true;

  Stream<AcquisitionSample> get samples => _sampleController.stream;
  Stream<String> get status => _statusController.stream;

  /// FFT frames computed by the native/console bridge.
  Stream<DaqFftFrame> get fftFrames => _fftController.stream;

  /// Waveform frames computed by the native/console bridge.
  Stream<DaqWaveFrame> get waveFrames => _waveController.stream;

  bool get isBridgeRunning => _bridgeClient.isRunning;

  void setRunning(bool value) {
    _isRunning = value;
  }

  void setBridgeSignalUnit(BridgeSignalUnit unit) {
    _bridgeSignalUnit = unit;
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
    _bridgeFrameSub?.cancel();
    _bridgeFftSub?.cancel();
    _bridgeWaveSub?.cancel();
    _bridgeBlockSub?.cancel();
    _bridgeStatusSub?.cancel();
    await _bridgeClient.dispose();
    await _sampleController.close();
    await _fftController.close();
    await _waveController.close();
    await _statusController.close();
  }

  void _onBridgeFrame(DaqFrame frame) {
    if (!_isRunning) {
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
        fftFrame: _lastFftFrame,
        waveFrame: _lastWaveFrame,
      ),
    );
  }

  void _onBridgeBlockFrame(DaqBlockFrame block) {
    if (!_isRunning) {
      return;
    }

    final Map<String, double> values = <String, double>{};
    final Map<String, double> rawRmsVolts = <String, double>{};

    for (int i = 0; i < _channels.length; i++) {
      final String channel = _channels[i];
      final double rms = i < block.channelRmsValues.length
          ? block.channelRmsValues[i]
          : 0.0;
      rawRmsVolts[channel] = rms;
      values[channel] = _bridgeSignalUnit == BridgeSignalUnit.accelerationG
          ? rms
          : (rms / 2.0).clamp(0.0, 1.2);
    }

    final double ai9Rms = block.channelRmsValues.length > 9
        ? block.channelRmsValues[9]
        : 0.0;
    final String unitLabel = _bridgeSignalUnit == BridgeSignalUnit.accelerationG
        ? 'g'
        : 'V';

    _statusController.add(
      'BLOCK ${block.sampleRateHz} Hz, block ${block.samplesRead}, channels ${block.channelRmsValues.length}, AI9 rms ${ai9Rms.toStringAsFixed(4)} $unitLabel',
    );

    if (!_fftController.isClosed) {
      _fftController.add(block.toFftFrame());
    }
    if (!_waveController.isClosed) {
      _waveController.add(block.toWaveFrame());
    }

    _sampleController.add(
      AcquisitionSample(
        values: values,
        rawRmsVolts: rawRmsVolts,
        sampleRateHz: block.sampleRateHz,
        samplesRead: block.samplesRead,
        fftFrame: block.toFftFrame(),
        waveFrame: block.toWaveFrame(),
      ),
    );
  }
}
