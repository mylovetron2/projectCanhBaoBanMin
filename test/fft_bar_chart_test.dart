import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mine_alert_flutter/fft_bar_chart.dart';

void main() {
  test('buildFftBarData keeps frequency x and lane metadata', () {
    final List<({String channel, List<double> freqs, List<double> mags})>
    fftSeries = <({String channel, List<double> freqs, List<double> mags})>[
      (channel: 'AI0', freqs: <double>[10, 20], mags: <double>[1.0, 2.0]),
      (
        channel: 'AI1',
        freqs: <double>[10, 20, 30],
        mags: <double>[0.5, 1.5, 2.5],
      ),
    ];

    final List<FftBarDatum> bars = buildFftBarData(
      fftSeries: fftSeries,
      colorForChannel: (String channel) =>
          channel == 'AI0' ? Colors.blue : Colors.red,
      axisXForFrequency: (double frequencyHz) => frequencyHz,
    );

    expect(bars.length, 5);
    expect(bars.first.x, 10.0);
    expect(bars.first.y, 1.0);
    expect(bars.first.color, Colors.blue);
    expect(bars.first.channel, 'AI0');
    expect(bars.first.channelIndex, 0);
    expect(bars.last.y, 2.5);
    expect(bars.last.channel, 'AI1');
    expect(bars.last.channelIndex, 1);
  });
}
