import 'dart:math';

import 'package:flutter/material.dart';

class FftBarDatum {
  const FftBarDatum({
    required this.channel,
    required this.channelIndex,
    required this.x,
    required this.y,
    required this.color,
    required this.width,
  });

  final String channel;
  final int channelIndex;
  final double x;
  final double y;
  final Color color;
  final double width;
}

List<FftBarDatum> buildFftBarData({
  required List<({String channel, List<double> freqs, List<double> mags})>
  fftSeries,
  required Color Function(String channel) colorForChannel,
  required double Function(double frequencyHz) axisXForFrequency,
}) {
  if (fftSeries.isEmpty) {
    return const <FftBarDatum>[];
  }

  final List<FftBarDatum> bars = <FftBarDatum>[];

  for (int seriesIndex = 0; seriesIndex < fftSeries.length; seriesIndex++) {
    final ({String channel, List<double> freqs, List<double> mags}) series =
        fftSeries[seriesIndex];
    final int count = min(series.freqs.length, series.mags.length);

    for (int index = 0; index < count; index++) {
      final double magnitude = series.mags[index];
      if (magnitude.isNaN || magnitude.isInfinite) {
        continue;
      }

      final double frequencyHz = series.freqs[index];
      final double baseX = axisXForFrequency(frequencyHz);
      bars.add(
        FftBarDatum(
          channel: series.channel,
          channelIndex: seriesIndex,
          x: baseX,
          y: magnitude.clamp(0.0, double.infinity),
          color: colorForChannel(series.channel),
          width: 0.0048,
        ),
      );
    }
  }

  return bars;
}

class FftBarChart extends StatelessWidget {
  const FftBarChart({
    required this.bars,
    required this.ticks,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    this.highlightBands = const <({double fromX, double toX, Color color})>[],
    super.key,
  });

  final List<FftBarDatum> bars;
  final List<({String label, double x})> ticks;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final List<({double fromX, double toX, Color color})> highlightBands;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FftBarChartPainter(
        bars: bars,
        ticks: ticks,
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        highlightBands: highlightBands,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _FftBarChartPainter extends CustomPainter {
  _FftBarChartPainter({
    required this.bars,
    required this.ticks,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.highlightBands,
  });

  final List<FftBarDatum> bars;
  final List<({String label, double x})> ticks;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final List<({double fromX, double toX, Color color})> highlightBands;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 40 || size.height < 40) {
      return;
    }

    final Rect chartRect = Rect.fromLTWH(
      64,
      8,
      size.width - 78,
      size.height - 32,
    );
    final Paint borderPaint = Paint()
      ..color = const Color(0xFFAEB7BF)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    final Paint majorGridPaint = Paint()
      ..color = const Color(0xFFBAC3CA)
      ..strokeWidth = 0.7;
    final Paint minorGridPaint = Paint()
      ..color = const Color(0xFFC8D0D7)
      ..strokeWidth = 0.5;
    final Paint fillPaint = Paint()..style = PaintingStyle.fill;
    final Paint laneBackgroundPaint = Paint()..color = const Color(0xFFEDEFF1);

    final List<int> channels =
        bars.map((FftBarDatum datum) => datum.channelIndex).toSet().toList()
          ..sort();
    final int laneCount = channels.isEmpty ? 1 : channels.length;
    final double laneGap = 12;
    final double totalGap = laneGap * (laneCount - 1);
    final double laneHeight = (chartRect.height - totalGap) / laneCount;

    final Map<int, Rect> laneRects = <int, Rect>{};
    for (int lane = 0; lane < laneCount; lane++) {
      final double top = chartRect.top + lane * (laneHeight + laneGap);
      laneRects[lane] = Rect.fromLTWH(
        chartRect.left,
        top,
        chartRect.width,
        laneHeight,
      );
    }

    for (int lane = 0; lane < laneCount; lane++) {
      final Rect laneRect = laneRects[lane]!;
      canvas.drawRect(laneRect, laneBackgroundPaint);
    }

    for (final ({double fromX, double toX, Color color}) band
        in highlightBands) {
      final double startX = _xToPixel(
        band.fromX.clamp(minX, maxX),
        chartRect.left,
        chartRect.right,
      );
      final double endX = _xToPixel(
        band.toX.clamp(minX, maxX),
        chartRect.left,
        chartRect.right,
      );
      if ((endX - startX).abs() < 1) {
        continue;
      }
      final Rect bandRect = Rect.fromLTRB(
        min(startX, endX),
        chartRect.top,
        max(startX, endX),
        chartRect.bottom,
      );
      final Paint bandPaint = Paint()..color = band.color;
      canvas.drawRect(bandRect, bandPaint);
    }

    for (int lane = 0; lane < laneCount; lane++) {
      final Rect laneRect = laneRects[lane]!;
      final double y0 = laneRect.bottom;
      canvas.drawLine(
        Offset(laneRect.left, y0),
        Offset(laneRect.right, y0),
        majorGridPaint,
      );
      canvas.drawLine(
        Offset(laneRect.left, laneRect.top),
        Offset(laneRect.right, laneRect.top),
        majorGridPaint,
      );
    }

    final List<double> minorFreqTicks = <double>[
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
    ];
    for (final double frequencyTick in minorFreqTicks) {
      final double xValue = _safeAxisX(frequencyTick);
      final double x = _xToPixel(xValue, chartRect.left, chartRect.right);
      _drawVerticalDashedLine(
        canvas,
        Offset(x, chartRect.top),
        Offset(x, chartRect.bottom),
        minorGridPaint,
      );
    }

    for (final ({String label, double x}) tick in ticks) {
      final double px = _xToPixel(tick.x, chartRect.left, chartRect.right);
      canvas.drawLine(
        Offset(px, chartRect.top),
        Offset(px, chartRect.bottom),
        majorGridPaint,
      );
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: tick.label,
          style: const TextStyle(
            color: Color(0xFF3A4A5A),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(px - textPainter.width / 2, chartRect.bottom + 6),
      );
    }

    final Map<int, FftBarDatum> laneAnchors = <int, FftBarDatum>{};
    for (final FftBarDatum bar in bars) {
      laneAnchors.putIfAbsent(bar.channelIndex, () => bar);
      final Rect? laneRect = laneRects[bar.channelIndex];
      if (laneRect == null) {
        continue;
      }
      final double left =
          _xToPixel(bar.x, laneRect.left, laneRect.right) -
          bar.width * laneRect.width / 2;
      final double right = left + bar.width * chartRect.width;
      final double top = _yToPixel(bar.y, laneRect.top, laneRect.bottom);
      final Rect rect = Rect.fromLTRB(left, top, right, laneRect.bottom);
      fillPaint.color = bar.color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1)),
        fillPaint,
      );
    }

    for (int lane = 0; lane < laneCount; lane++) {
      final Rect laneRect = laneRects[lane]!;
      final FftBarDatum? anchor = laneAnchors[lane];
      final Color laneColor = anchor?.color ?? const Color(0xFF546E7A);

      final Paint baselinePaint = Paint()
        ..color = laneColor
        ..strokeWidth = 1.2;
      canvas.drawLine(
        Offset(laneRect.left, laneRect.bottom),
        Offset(laneRect.right, laneRect.bottom),
        baselinePaint,
      );

      final String laneLabel = anchor?.channel ?? 'CH${lane + 1}';
      final TextPainter laneText = TextPainter(
        text: TextSpan(
          text: laneLabel,
          style: TextStyle(
            color: laneColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      laneText.paint(canvas, Offset(8, laneRect.top + 2));
    }

    canvas.drawRect(chartRect, borderPaint);
  }

  double _safeAxisX(double frequencyHz) {
    const double minHz = 10.0;
    const double maxHz = 5000.0;
    final double clamped = frequencyHz.clamp(minHz, maxHz);
    final double minLog = log(minHz);
    final double maxLog = log(maxHz);
    final double normalized = (log(clamped) - minLog) / (maxLog - minLog);
    return minX + normalized * (maxX - minX);
  }

  void _drawVerticalDashedLine(
    Canvas canvas,
    Offset from,
    Offset to,
    Paint paint,
  ) {
    const double dash = 4;
    const double gap = 4;
    double y = from.dy;
    while (y < to.dy) {
      final double y2 = min(y + dash, to.dy);
      canvas.drawLine(Offset(from.dx, y), Offset(to.dx, y2), paint);
      y += dash + gap;
    }
  }

  double _xToPixel(double value, double left, double right) {
    final double normalized = ((value - minX) / (maxX - minX)).clamp(0.0, 1.0);
    return left + normalized * (right - left);
  }

  double _yToPixel(double value, double top, double bottom) {
    final double normalized = ((value - minY) / (maxY - minY)).clamp(0.0, 1.0);
    return bottom - normalized * (bottom - top);
  }

  @override
  bool shouldRepaint(covariant _FftBarChartPainter oldDelegate) => true;
}
