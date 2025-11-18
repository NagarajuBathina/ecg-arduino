import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../provider/BlueProvider.dart';
import 'chart_data.dart';

class EcgScreen extends StatefulWidget {
  const EcgScreen({super.key});

  @override
  State<EcgScreen> createState() => _EcgScreenState();
}

class _EcgScreenState extends State<EcgScreen> {
  late List<ChartData> _points;

  int maxSamples = 500; // Number of visible points
  int _xIndex = 0; // Current floating cursor position

  Stream<Uint8List>? _ecgStream;
  StreamSubscription<Uint8List>? _subscription;
  late BlueProvider blueProvider;

  DateTime lastUpdate = DateTime.now();

  double amplitude = 3.0; // Adjust ECG height
  double baselineOffset = -400; // Move signal vertically

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Initialize buffer
    _points = List<ChartData>.generate(
      maxSamples,
      (index) => ChartData(index.toDouble(), null),
    );

    // After build → attach BT listener
    WidgetsBinding.instance.addPostFrameCallback((_) {
      blueProvider = Provider.of<BlueProvider>(context, listen: false);
      _ecgStream = blueProvider.onDataReceived;
      _listenToEcg();
    });
  }

  void _listenToEcg() {
    _subscription = _ecgStream?.listen((data) {
      // print(data);
      if (!mounted) return;

      // Expect 6-byte ECG packet
      if (data.length != 6 || data[0] != 255) return;

      // Limit incoming updates (slows scrolling visibly)
      final now = DateTime.now();
      if (now.difference(lastUpdate).inMilliseconds < 15) return;
      lastUpdate = now;

      int a = data[1];
      int b = data[2];

      // Decode 10-bit ECG value
      int rawEcg = (a << 2) | ((b & 0xC0) >> 6);
      print(rawEcg);

      // Scale & offset for visual effect
      double ecgValue = (rawEcg.toDouble() * amplitude) + baselineOffset;

      // Insert ECG sample at the floating head index
      _points[_xIndex] = ChartData(_xIndex.toDouble(), ecgValue);

      // Create floating gap (blank space)
      int gapSize = 30;
      for (int i = 1; i <= gapSize; i++) {
        int gapIndex = (_xIndex + i) % maxSamples;
        _points[gapIndex] = ChartData(gapIndex.toDouble(), null);
      }

      // Move floating cursor
      _xIndex = (_xIndex + 1) % maxSamples;

      setState(() {});
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    super.dispose();
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = context.watch<BlueProvider>().isConnected;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("ECG Monitor", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green.shade700,
        actions: [
          IconButton(
            onPressed: () => blueProvider.sendData('5'),
            icon: const Icon(Icons.play_arrow),
          ),
          IconButton(
            onPressed: () => blueProvider.sendData('0'),
            icon: const Icon(Icons.stop, color: Colors.red),
          ),
        ],
      ),
      body: Center(
        child: isConnected
            ? SfCartesianChart(
                plotAreaBorderWidth: 0,
                primaryXAxis: NumericAxis(
                  isVisible: false,
                  minimum: 0,
                  maximum: maxSamples.toDouble() - 1,
                ),
                primaryYAxis: NumericAxis(
                  isVisible: false,
                  minimum: -2000,
                  maximum: 2000,
                ),
                series: <LineSeries<ChartData, double>>[
                  LineSeries<ChartData, double>(
                    color: Colors.greenAccent,
                    width: 3,
                    dataSource: _points,
                    xValueMapper: (ChartData d, _) => d.x,
                    yValueMapper: (ChartData d, _) => d.y,
                    emptyPointSettings:
                        EmptyPointSettings(mode: EmptyPointMode.gap),
                  ),
                ],
              )
            : const Text("Device not connected",
                style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
    );
  }
}
