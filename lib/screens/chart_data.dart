import 'dart:async';

import 'package:ecg_arduino/app/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class ChartData {
  final double x;
  final double? y;
  ChartData(this.x, this.y);
}

class EcgScreen extends StatefulWidget {
  const EcgScreen({super.key});
  @override
  State<EcgScreen> createState() => _EcgScreenState();
}

class _EcgScreenState extends State<EcgScreen> {
  late List<ChartData>
      _points; // Total number of points visible on the screen at one time final
  int maxSamples =
      500; // The current "x" position (index) where the chart is drawing
  int _xIndex = 0;
  Timer? timer;
  int arrayIndex = 0; // Current simulation array
  int valueIndex = 0; // Position inside simulation array
  double baseline = 2.45; // you can fine-tune this
  double amplitude = 300; // increase for bigger waves (300–800)
  final List<List<double>> allArrays = [
    ecg1,
    ecg2,
    ecg3,
    ecg4,
    ecg5,
    ecg6,
    ecg7
  ];
  @override
  void initState() {
    super.initState();
    _points = List<ChartData>.generate(
      maxSamples,
      (index) => ChartData(index.toDouble(), 0),
    );
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    startEcgSimulation();
  }

  void startEcgSimulation() {
    timer = Timer.periodic(const Duration(milliseconds: 15), (t) {
      addNextSample();
    });
  }

  void addNextSample() {
    // 1. Get the 'y' value from your simulation data
    List<double> currentArray = allArrays[arrayIndex];
    // Check if simulation array is done, loop to next
    if (valueIndex >= currentArray.length) {
      arrayIndex = (arrayIndex + 1) % allArrays.length;
      valueIndex = 0;
    }
    double rawValue = currentArray[valueIndex];
    valueIndex++;
    double scaled = (rawValue - baseline) * amplitude;

    // 2. Update the chart data AT THE CURRENT X-INDEX // We are *updating* the list, not adding to it.
    _points[_xIndex] = ChartData(_xIndex.toDouble(),
        scaled); // 3. Create the "draw head" gap // We set the *next* few points to 'null' to create the blank space // that shows the screen refreshing.
    int gapSize = 40; // How wide the blank gap is
    for (int i = 1; i <= gapSize; i++) {
      int gapIndex = (_xIndex + i) % maxSamples;
      // Wrap around
      _points[gapIndex] = ChartData(gapIndex.toDouble(), null);
    }
    // 4. Move the x-index for the next update
    // // This makes it wrap around from (maxSamples - 1) back to 0.
    _xIndex = (_xIndex + 1) % maxSamples;
    setState(() {});
  } // This function is no longer needed as we don't add/remove points

  double normalize(double value, List<double> array) {
    // This simple normalization can be weak if the array has one big spike. // A more stable way is to use a fixed min/max if you know it. // But this works for simulation.
    double mean = array.reduce((a, b) => a + b) / array.length;
    return (value - mean) * 800;
    // adjust scale as needed
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
      appBar: AppBar(
        title: const Text("ECG Monitor", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green.shade700,
      ),
      body: Padding(
          padding: const EdgeInsets.all(0),
          child: SfCartesianChart(
              primaryXAxis: NumericAxis(
                isVisible: false,
                minimum: 0,
                maximum: maxSamples.toDouble() - 1,
              ),
              primaryYAxis: NumericAxis(
                minimum: -400,
                maximum: 1200,
                isVisible: false,
              ),
              series: <LineSeries<ChartData, double>>[
                LineSeries<ChartData, double>(
                  color: Colors.greenAccent,
                  width: 3,
                  dataSource: _points,
                  xValueMapper: (ChartData data, _) => data.x,
                  yValueMapper: (ChartData data, _) => data.y,
                ),
              ])),
    );
  }
}
