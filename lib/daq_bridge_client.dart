import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

class DaqFrame {
  DaqFrame({
    required this.sampleRateHz,
    required this.samplesRead,
    required this.channelRmsVolts,
  });

  final int sampleRateHz;
  final int samplesRead;
  final List<double> channelRmsVolts;
}

class DaqFftFrame {
  DaqFftFrame({
    required this.sampleRateHz,
    required this.samplesRead,
    required this.channelCount,
    required this.binCount,
    required this.magnitudes,
  });

  /// Hardware sample rate in Hz (e.g. 10000).
  final int sampleRateHz;

  /// Number of raw samples per block (used to compute fftSize = nextPow2(samplesRead)).
  final int samplesRead;
  final int channelCount;

  /// Frequency-domain bins per channel. Total magnitudes.length == channelCount * binCount.
  final int binCount;

  /// Channel-major flat array: [ch0_b0, ch0_b1, ..., ch1_b0, ...].
  final List<double> magnitudes;

  /// Frequency in Hz for bin index [k].
  double freqHz(int k) => k * sampleRateHz / _nextPow2(samplesRead).toDouble();

  /// Magnitude list for channel [chIdx].
  List<double> channelMags(int chIdx) =>
      magnitudes.sublist(chIdx * binCount, (chIdx + 1) * binCount);

  static int _nextPow2(int n) {
    int p = 1;
    while (p < n) {
      p <<= 1;
    }
    return p;
  }

  // Expose for use in UI layer.
  // ignore: library_private_types_in_public_api
  static int nextPow2(int n) => _nextPow2(n);
}

class DaqWaveFrame {
  DaqWaveFrame({
    required this.sampleRateHz,
    required this.samplesRead,
    required this.decimStep,
    required this.channelCount,
    required this.channelSamples,
  });

  final int sampleRateHz;
  final int samplesRead;

  /// Decimation step used by the C bridge (e.g. 5 → every 5th sample).
  final int decimStep;
  final int channelCount;

  /// Raw sample values per channel: channelSamples[ch][i].
  final List<List<double>> channelSamples;

  /// Time in seconds for decimated sample index [i].
  double timeMs(int i) => (i * decimStep) / sampleRateHz * 1000.0;
}

class DaqBlockFrame {
  DaqBlockFrame({
    required this.sampleRateHz,
    required this.samplesRead,
    required this.channelCount,
    required this.binCount,
    required this.decimStep,
    required this.channelRmsValues,
    required this.magnitudes,
    required this.channelSamples,
  });

  final int sampleRateHz;
  final int samplesRead;
  final int channelCount;
  final int binCount;
  final int decimStep;
  final List<double> channelRmsValues;
  final List<double> magnitudes;
  final List<List<double>> channelSamples;

  DaqFftFrame toFftFrame() {
    return DaqFftFrame(
      sampleRateHz: sampleRateHz,
      samplesRead: samplesRead,
      channelCount: channelCount,
      binCount: binCount,
      magnitudes: magnitudes,
    );
  }

  DaqWaveFrame toWaveFrame() {
    return DaqWaveFrame(
      sampleRateHz: sampleRateHz,
      samplesRead: samplesRead,
      decimStep: decimStep,
      channelCount: channelCount,
      channelSamples: channelSamples,
    );
  }

  DaqFrame toRmsFrame() {
    return DaqFrame(
      sampleRateHz: sampleRateHz,
      samplesRead: samplesRead,
      channelRmsVolts: channelRmsValues,
    );
  }
}

class DaqBridgeClient {
  static const MethodChannel _nativeMethodChannel = MethodChannel(
    'mine_alert/daq_bridge_method',
  );
  static const EventChannel _nativeEventChannel = EventChannel(
    'mine_alert/daq_bridge_events',
  );

  final StreamController<DaqFrame> _frameController =
      StreamController<DaqFrame>.broadcast();
  final StreamController<DaqFftFrame> _fftFrameController =
      StreamController<DaqFftFrame>.broadcast();
  final StreamController<DaqWaveFrame> _waveFrameController =
      StreamController<DaqWaveFrame>.broadcast();
  final StreamController<DaqBlockFrame> _blockFrameController =
      StreamController<DaqBlockFrame>.broadcast();
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  Process? _process;
  StreamSubscription<dynamic>? _nativeEventSub;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  bool _nativeRunning = false;
  bool _isDisposed = false;

  Stream<DaqFrame> get frames => _frameController.stream;
  Stream<DaqFftFrame> get fftFrames => _fftFrameController.stream;
  Stream<DaqWaveFrame> get waveFrames => _waveFrameController.stream;
  Stream<DaqBlockFrame> get blockFrames => _blockFrameController.stream;
  Stream<String> get status => _statusController.stream;

  bool get isRunning => Platform.isWindows ? _nativeRunning : _process != null;

  Future<void> start({
    required String executablePath,
    List<String> args = const <String>[],
  }) async {
    if (_isDisposed) {
      throw StateError('DaqBridgeClient is disposed');
    }

    if (isRunning) {
      return;
    }

    if (Platform.isWindows) {
      await _ensureNativeEventSubscription();
      try {
        await _nativeMethodChannel.invokeMethod<void>(
          'startBridge',
          <String, Object?>{'executablePath': executablePath, 'args': args},
        );
        _nativeRunning = true;
        _emitStatus('Bridge started (in-process Windows NI-DAQmx)');
      } catch (error) {
        _nativeRunning = false;
        _emitStatus('Bridge start failed: $error');
        rethrow;
      }
      return;
    }

    try {
      _process = await Process.start(executablePath, args, runInShell: false);
      _emitStatus(
        'Bridge started (pid ${_process!.pid}): $executablePath ${args.join(' ')}',
      );

      _stdoutSub = _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_parseLine);

      _stderrSub = _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((String line) {
            if (line.trim().isNotEmpty) {
              _emitStatus('Bridge stderr: $line');
            }
          });

      final Process processAtStart = _process!;
      unawaited(
        processAtStart.exitCode.then((int code) {
          _emitStatus('Bridge exited with code $code');
          if (identical(_process, processAtStart)) {
            _disposeProcessOnly();
          }
        }),
      );
    } catch (error) {
      _emitStatus('Bridge start failed: $error');
      _disposeProcessOnly();
      rethrow;
    }
  }

  Future<void> stop() async {
    if (Platform.isWindows) {
      if (!_nativeRunning) {
        return;
      }

      try {
        await _nativeMethodChannel.invokeMethod<void>('stopBridge');
      } catch (_) {
        // Ignore stop errors; bridge state is best-effort during shutdown.
      }
      _nativeRunning = false;
      _emitStatus('Bridge stopped');
      return;
    }

    final Process? process = _process;
    if (process == null) {
      return;
    }

    try {
      if (Platform.isWindows) {
        // Kill process tree to avoid orphan DAQ bridge after app closes.
        await Process.run('taskkill', <String>[
          '/PID',
          process.pid.toString(),
          '/T',
          '/F',
        ]);
      } else {
        process.kill(ProcessSignal.sigterm);
      }
    } catch (_) {
      process.kill();
    }

    unawaited(
      process.exitCode.timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      ),
    );

    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    _stdoutSub = null;
    _stderrSub = null;
    if (identical(_process, process)) {
      _process = null;
    }
    _emitStatus('Bridge stopped');
  }

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    await stop();
    await _nativeEventSub?.cancel();
    await _frameController.close();
    await _fftFrameController.close();
    await _waveFrameController.close();
    await _blockFrameController.close();
    await _statusController.close();
  }

  void _parseLine(String line) {
    if (line.trim().isEmpty) {
      return;
    }

    if (line.startsWith('DATA_MULTI,')) {
      final List<String> parts = line.split(',');
      if (parts.length < 5) {
        _emitStatus('Malformed DATA_MULTI line: $line');
        return;
      }

      final int? rate = int.tryParse(parts[1]);
      final int? samples = int.tryParse(parts[2]);
      final int? channelCount = int.tryParse(parts[3]);
      if (rate == null || samples == null || channelCount == null) {
        _emitStatus('Invalid DATA_MULTI header: $line');
        return;
      }

      if (channelCount <= 0 || parts.length != 4 + channelCount) {
        _emitStatus('DATA_MULTI channel count mismatch: $line');
        return;
      }

      final List<double> rmsValues = <double>[];
      for (int i = 0; i < channelCount; i++) {
        final double? rms = double.tryParse(parts[4 + i]);
        if (rms == null) {
          _emitStatus('Invalid DATA_MULTI numeric value: $line');
          return;
        }
        rmsValues.add(rms);
      }

      _frameController.add(
        DaqFrame(
          sampleRateHz: rate,
          samplesRead: samples,
          channelRmsVolts: rmsValues,
        ),
      );
      return;
    }

    if (line.startsWith('FFT_MULTI,')) {
      final List<String> parts = line.split(',');
      // Header: FFT_MULTI,<rate>,<samplesRead>,<channelCount>,<binCount>  → 5 fields
      if (parts.length < 6) {
        _emitStatus('Malformed FFT_MULTI: insufficient fields');
        return;
      }
      final int? rate = int.tryParse(parts[1]);
      final int? samplesRead = int.tryParse(parts[2]);
      final int? channelCount = int.tryParse(parts[3]);
      final int? binCount = int.tryParse(parts[4]);
      if (rate == null ||
          samplesRead == null ||
          channelCount == null ||
          binCount == null) {
        _emitStatus('FFT_MULTI invalid header values');
        return;
      }
      final int expected = 5 + channelCount * binCount;
      if (parts.length != expected) {
        _emitStatus(
          'FFT_MULTI size mismatch: got ${parts.length}, expected $expected',
        );
        return;
      }
      final List<double> mags = List<double>.filled(
        channelCount * binCount,
        0.0,
      );
      for (int i = 0; i < channelCount * binCount; i++) {
        final double? v = double.tryParse(parts[5 + i]);
        if (v == null) {
          _emitStatus('FFT_MULTI invalid magnitude at index $i');
          return;
        }
        mags[i] = v;
      }
      if (!_fftFrameController.isClosed) {
        _fftFrameController.add(
          DaqFftFrame(
            sampleRateHz: rate,
            samplesRead: samplesRead,
            channelCount: channelCount,
            binCount: binCount,
            magnitudes: mags,
          ),
        );
      }
      return;
    }

    if (line.startsWith('BLOCK_MULTI,')) {
      final List<String> parts = line.split(',');
      // Header: BLOCK_MULTI,<rate>,<samplesRead>,<channelCount>,<binCount>,<decimStep>
      if (parts.length < 7) {
        _emitStatus('Malformed BLOCK_MULTI: insufficient fields');
        return;
      }
      final int? rate = int.tryParse(parts[1]);
      final int? samplesRead = int.tryParse(parts[2]);
      final int? channelCount = int.tryParse(parts[3]);
      final int? binCount = int.tryParse(parts[4]);
      final int? decimStep = int.tryParse(parts[5]);
      if (rate == null ||
          samplesRead == null ||
          channelCount == null ||
          binCount == null ||
          decimStep == null ||
          channelCount <= 0 ||
          binCount <= 0 ||
          decimStep <= 0) {
        _emitStatus('BLOCK_MULTI invalid header values');
        return;
      }

      final int outCount = (samplesRead + decimStep - 1) ~/ decimStep;
      final int rmsStart = 6;
      final int fftStart = rmsStart + channelCount;
      final int waveStart = fftStart + (channelCount * binCount);
      final int expected = waveStart + (channelCount * outCount);
      if (parts.length != expected) {
        _emitStatus(
          'BLOCK_MULTI size mismatch: got ${parts.length}, expected $expected',
        );
        return;
      }

      final List<double> rmsValues = List<double>.filled(channelCount, 0.0);
      for (int i = 0; i < channelCount; i++) {
        final double? v = double.tryParse(parts[rmsStart + i]);
        if (v == null) {
          _emitStatus('BLOCK_MULTI invalid RMS at index $i');
          return;
        }
        rmsValues[i] = v;
      }

      final List<double> mags = List<double>.filled(
        channelCount * binCount,
        0.0,
      );
      for (int i = 0; i < mags.length; i++) {
        final double? v = double.tryParse(parts[fftStart + i]);
        if (v == null) {
          _emitStatus('BLOCK_MULTI invalid FFT magnitude at index $i');
          return;
        }
        mags[i] = v;
      }

      final List<List<double>> channelSamples = List<List<double>>.generate(
        channelCount,
        (int ch) {
          final int offset = waveStart + ch * outCount;
          return List<double>.generate(outCount, (int i) {
            return double.tryParse(parts[offset + i]) ?? 0.0;
          });
        },
      );

      final DaqBlockFrame block = DaqBlockFrame(
        sampleRateHz: rate,
        samplesRead: samplesRead,
        channelCount: channelCount,
        binCount: binCount,
        decimStep: decimStep,
        channelRmsValues: rmsValues,
        magnitudes: mags,
        channelSamples: channelSamples,
      );

      if (!_blockFrameController.isClosed) {
        _blockFrameController.add(block);
      }
      return;
    }

    if (line.startsWith('WAVE_MULTI,')) {
      final List<String> parts = line.split(',');
      // Header: WAVE_MULTI,<rate>,<samplesRead>,<channelCount>,<decimStep> → 5 fields
      if (parts.length < 6) return;
      final int? rate = int.tryParse(parts[1]);
      final int? samplesRead = int.tryParse(parts[2]);
      final int? channelCount = int.tryParse(parts[3]);
      final int? decimStep = int.tryParse(parts[4]);
      if (rate == null ||
          samplesRead == null ||
          channelCount == null ||
          decimStep == null ||
          decimStep <= 0) {
        return;
      }
      final int outCount = (samplesRead + decimStep - 1) ~/ decimStep;
      if (parts.length != 5 + channelCount * outCount) return;
      final List<List<double>> channelSamples = List<List<double>>.generate(
        channelCount,
        (int ch) {
          final int offset = 5 + ch * outCount;
          return List<double>.generate(
            outCount,
            (int i) => double.tryParse(parts[offset + i]) ?? 0.0,
          );
        },
      );
      if (!_waveFrameController.isClosed) {
        _waveFrameController.add(
          DaqWaveFrame(
            sampleRateHz: rate,
            samplesRead: samplesRead,
            decimStep: decimStep,
            channelCount: channelCount,
            channelSamples: channelSamples,
          ),
        );
      }
      return;
    }

    if (line.startsWith('DATA,')) {
      final List<String> parts = line.split(',');
      if (parts.length < 5) {
        _emitStatus('Malformed DATA line: $line');
        return;
      }

      final int? rate = int.tryParse(parts[1]);
      final int? samples = int.tryParse(parts[2]);
      final double? rms = double.tryParse(parts[3]);
      final double? peak = double.tryParse(parts[4]);

      if (rate == null || samples == null || rms == null || peak == null) {
        _emitStatus('Invalid numeric DATA line: $line');
        return;
      }

      _frameController.add(
        DaqFrame(
          sampleRateHz: rate,
          samplesRead: samples,
          channelRmsVolts: <double>[rms],
        ),
      );
      return;
    }

    if (line.startsWith('ERROR,')) {
      _emitStatus(line);
      return;
    }

    _emitStatus(line);
  }

  void _disposeProcessOnly() {
    unawaited(_stdoutSub?.cancel());
    unawaited(_stderrSub?.cancel());
    _stdoutSub = null;
    _stderrSub = null;
    _process = null;
  }

  Future<void> _ensureNativeEventSubscription() async {
    if (_nativeEventSub != null) {
      return;
    }

    _nativeEventSub = _nativeEventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is String) {
          _handleNativeEvent(event);
        } else {
          _emitStatus('Bridge event: $event');
        }
      },
      onError: (Object error) {
        _nativeRunning = false;
        _emitStatus('Bridge event error: $error');
      },
      onDone: () {
        _nativeRunning = false;
      },
    );
  }

  void _handleNativeEvent(String line) {
    if (line.startsWith('BRIDGE_STARTED,')) {
      _nativeRunning = true;
      _emitStatus(line);
      return;
    }

    if (line.startsWith('BRIDGE_STOPPED,')) {
      _nativeRunning = false;
      final List<String> parts = line.split(',');
      final String code = parts.length > 1 ? parts[1] : '0';
      _emitStatus('Bridge exited with code $code');
      return;
    }

    _parseLine(line);
  }

  void _emitStatus(String message) {
    if (_isDisposed || _statusController.isClosed) {
      return;
    }
    _statusController.add(message);
  }
}
