import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

class DaqBridgeClient {
  final StreamController<DaqFrame> _frameController =
      StreamController<DaqFrame>.broadcast();
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  Process? _process;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  bool _isDisposed = false;

  Stream<DaqFrame> get frames => _frameController.stream;
  Stream<String> get status => _statusController.stream;

  bool get isRunning => _process != null;

  Future<void> start({
    required String executablePath,
    List<String> args = const <String>[],
  }) async {
    if (_isDisposed) {
      throw StateError('DaqBridgeClient is disposed');
    }

    if (_process != null) {
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
    await _frameController.close();
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

  void _emitStatus(String message) {
    if (_isDisposed || _statusController.isClosed) {
      return;
    }
    _statusController.add(message);
  }
}
