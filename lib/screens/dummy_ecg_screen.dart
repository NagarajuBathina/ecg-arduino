// ecg_real_samples_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'chart_data.dart';

class EcgRealSamplesScreen extends StatefulWidget {
  const EcgRealSamplesScreen({super.key});

  @override
  State<EcgRealSamplesScreen> createState() => _EcgRealSamplesScreenState();
}

class _EcgRealSamplesScreenState extends State<EcgRealSamplesScreen> {
  // Chart buffer size (how many x points visible on screen)
  final int maxSamples = 800;

  // Sample rate used to generate beats (samples per second)
  final int sampleRate = 360;

  late List<ChartData> points;
  Timer? timer;

  // playback pointers
  int xIndex = 0;
  int beatIndex = 0;
  int sampleIndexInBeat = 0;

  // gain to convert mV -> chart pixels (adjust visually)
  final double gain = 1200.0;

  // pre-generated realistic beats (mV)
  late final List<List<double>> beats;

  @override
  void initState() {
    super.initState();

    // initialize chart buffer with nulls so empty segments appear as gaps
    points = List.generate(maxSamples, (i) => ChartData(i.toDouble(), null));

    // create realistic beat templates (360 samples each ~ 1 second at 60 BPM)
    beats = [
      generateEcgBeat(sampleRate, 1.0,
          rAmplitude: 1.0, tAmplitude: 0.35, pAmplitude: 0.12),
      generateEcgBeat(sampleRate, 1.0,
          rAmplitude: 1.05, tAmplitude: 0.30, pAmplitude: 0.14),
      generateEcgBeat(sampleRate, 0.95,
          rAmplitude: 0.95, tAmplitude: 0.36, pAmplitude: 0.13),
    ];

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    startSweep();
  }

  void startSweep() {
    // Medium sweep speed: tick ~14ms => ~71 updates/sec
    timer = Timer.periodic(const Duration(milliseconds: 5), (_) {
      final currentBeat = beats[beatIndex];

      // If we reached the end of current beat, move to next beat (introduces variability)
      if (sampleIndexInBeat >= currentBeat.length) {
        beatIndex = (beatIndex + 1) % beats.length;
        sampleIndexInBeat = 0;
      }

      // get mV sample and scale
      double mv = currentBeat[sampleIndexInBeat++];
      double y = mv * gain;

      // push into circular buffer
      points[xIndex] = ChartData(xIndex.toDouble(), y);

      // advance x index (wrap)
      xIndex = (xIndex + 1) % maxSamples;

      // create tiny sweep head gap (clear next sample) — gives the "moving head" effect
      points[(xIndex + 1) % maxSamples] =
          ChartData((xIndex + 1).toDouble(), null);

      // redraw
      setState(() {});
    });
  }

  /// Generate a single ECG beat sampled at [fs] Hz and lasting [durationSec] seconds.
  /// Returns a list of samples in millivolts (mV).
  ///
  /// The beat uses Gaussian bumps for P, Q, R, S, and T with physiologic widths and timing.
  List<double> generateEcgBeat(int fs, double durationSec,
      {double rAmplitude = 1.0,
      double tAmplitude = 0.35,
      double pAmplitude = 0.12}) {
    final int n = (fs * durationSec).round();
    final List<double> out = List<double>.filled(n, 0.0);

    // timing positions (fractions of duration)
    final double pCenter = 0.16 * durationSec;
    final double qCenter = 0.36 * durationSec;
    final double rCenter = 0.40 * durationSec;
    final double sCenter = 0.43 * durationSec;
    final double tCenter = 0.62 * durationSec;

    // widths in seconds (physiologic)
    const double pSigma = 0.025; // P-wave ~ 25 ms sigma
    const double qSigma = 0.012; // Q narrow
    const double rSigma = 0.010; // very narrow R spike
    const double sSigma = 0.018;
    const double tSigma = 0.060; // T-wave broad

    // small physiologic baseline wander (very low freq) - optional, set low amplitude
    const double baselineAmp = 0.02; // mV
    const double baselineFreq = 0.33; // Hz

    for (int i = 0; i < n; i++) {
      double t = i / fs; // seconds from beat start

      // P-wave (small, rounded)
      out[i] += pAmplitude * gaussian(t, pCenter, pSigma);

      // Q (small negative)
      out[i] += -0.18 * gaussian(t, qCenter, qSigma);

      // R (large positive sharp spike)
      out[i] += rAmplitude * gaussian(t, rCenter, rSigma);

      // S (negative after R)
      out[i] += -0.25 * gaussian(t, sCenter, sSigma);

      // T-wave (broad positive)
      out[i] += tAmplitude * gaussian(t, tCenter, tSigma);

      // optional gentle baseline wander
      out[i] += baselineAmp * sin(2 * pi * baselineFreq * t);
    }

    // optional small smoothing to avoid ultra-sharp discrete spikes
    return smooth(out, window: 3);
  }

  /// simple Gaussian centered at mu with width sigma
  double gaussian(double x, double mu, double sigma) {
    final double z = (x - mu) / sigma;
    return exp(-0.5 * z * z);
  }

  /// small moving-average smoothing
  List<double> smooth(List<double> data, {int window = 3}) {
    if (window <= 1) return List.from(data);
    final int n = data.length;
    final List<double> out = List<double>.filled(n, 0.0);
    final int w = window;
    for (int i = 0; i < n; i++) {
      int start = max(0, i - w ~/ 2);
      int end = min(n - 1, i + w ~/ 2);
      double sum = 0;
      for (int j = start; j <= end; j++) {
        sum += data[j];
      }
      out[i] = sum / (end - start + 1);
    }
    return out;
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SfCartesianChart(
          plotAreaBorderWidth: 0,
          primaryXAxis: NumericAxis(
              isVisible: false, minimum: 0, maximum: maxSamples.toDouble()),
          primaryYAxis:
              NumericAxis(isVisible: false, minimum: -2000, maximum: 2000),
          series: <LineSeries<ChartData, double>>[
            LineSeries<ChartData, double>(
              color: Colors.greenAccent,
              width: 3,
              dataSource: points,
              xValueMapper: (ChartData d, _) => d.x,
              yValueMapper: (ChartData d, _) => d.y,
              emptyPointSettings: EmptyPointSettings(mode: EmptyPointMode.gap),
            )
          ],
        ),
      ),
    );
  }
}
