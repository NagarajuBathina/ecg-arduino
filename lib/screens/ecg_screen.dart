// ignore_for_file: prefer_const_constructors, library_private_types_in_public_api

import 'dart:async';

import 'package:ecg_arduino/provider/BlueProvider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EcgScreen extends StatefulWidget {
  const EcgScreen({super.key});

  @override
  _EcgScreenState createState() => _EcgScreenState();
}

class _EcgScreenState extends State<EcgScreen> {
  final CircularBuffer ecgData = CircularBuffer(1800);
  double currentX = 0;
//  static const int maxDataPoints = 600; // 3 seconds of data at 200Hz
  static const double xAxisDuration = 10.0; // 3 seconds window
  static const double minY = -200;
  static const double maxY = 500;
  bool isReading = false;
  late BlueProvider _blueProvider;
  StreamSubscription? _dataSubscription;
  final EcgProcessor _processor = EcgProcessor();
  Timer? _updateTimer;
  static const Duration animationDuration = Duration(milliseconds: 200);
  @override
  void initState() {
    super.initState();
    _blueProvider = Provider.of<BlueProvider>(context, listen: false);
    _startChartUpdate();
  }

  void _addDataPoint(double value) {
    if (!mounted) return;
    print(value);
    ecgData.add(value);
    setState(() {}); // Trigger chart redraw
  }

  void _startReading() {
    if (!mounted) return;
    setState(() {
      isReading = true;
      currentX = 0;
    });

    // Send command to start ECG readings
    _blueProvider.sendData('5');

    // Accumulate processed values and update in batches
    final List<double> buffer = [];
    const int batchIntervalMs = 1000;

    // Setup data listener
    _dataSubscription = _blueProvider.onDataReceived.listen((data) {
      List<double> processedValues = _processor.processData(data);
      buffer.addAll(processedValues);

      // Periodically flush buffer to add data points
      Timer(Duration(milliseconds: batchIntervalMs), () {
        if (buffer.isNotEmpty) {
          buffer.forEach(_addDataPoint);
          buffer.clear();
        }
      });
    });
  }

  void _stopReading() {
    if (!mounted) return;
    setState(() {
      isReading = false;
    });

    // Send command to stop ECG readings
    _blueProvider.sendData('1'); // ASCII '1'

    // Cancel data subscription
    _dataSubscription?.cancel();
    _dataSubscription = null;
    ecgData.clear();
    // Reset chart to empty state
    _stopChartUpdate();
  }

  void _startChartUpdate() {
    _updateTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) {
        _updateTimer?.cancel();
        return;
      }
      setState(() {}); // Trigger chart redraw at 60Hz
    });
  }

  void _stopChartUpdate() {
    _updateTimer?.cancel();
  }

  @override
  void dispose() {
    // Cancel timer first
    _updateTimer?.cancel();
    _updateTimer = null;

    // Then cancel subscription
    _dataSubscription?.cancel();
    _dataSubscription = null;

    // Finally call super.dispose()
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          ElevatedButton(
            onPressed: () {
              if (isReading) {
                _stopReading();
              } else {
                _startReading();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isReading ? Colors.red[300] : Colors.grey[300],
            ),
            child: Text(isReading ? 'STOP' : 'START'),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox(
          height: 400,
          child: LineChart(
              swapAnimationDuration: animationDuration,
              swapAnimationCurve: Curves.easeInOut,
              LineChartData(
                minX: 0,
                maxX: xAxisDuration,
                minY: minY,
                maxY: maxY,
                backgroundColor: Colors.black,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 200,
                  verticalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey[300],
                      strokeWidth: 0.5,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: Colors.grey[300],
                      strokeWidth: 0.5,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 12),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: 100,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(fontSize: 12),
                        );
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.black, width: 1),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: isReading ? ecgData.getSpots() : [],
                    isCurved: true,
                    curveSmoothness: 0.1,
                    color: Colors.greenAccent,
                    barWidth: 2,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                    isStrokeCapRound: true,
                  ),
                ],
              )),
        ),
      ),
    );
  }
}

class CircularBuffer {
  final int size;
  final List<double> _buffer;
  bool _hasData = false;

  CircularBuffer(this.size) : _buffer = List.filled(size, 0);

  void add(double value) {
    // Shift all values to the right
    for (int i = size - 1; i > 0; i--) {
      _buffer[i] = _buffer[i - 1];
    }
    // Add new value at the start
    _buffer[0] = value;
    _hasData = true;
  }

  void clear() {
    _buffer.fillRange(0, size, 0);
    _hasData = false;
  }

  List<FlSpot> getSpots() {
    if (!_hasData) return [];

    List<FlSpot> spots = [];

    // Start point at x=0.1, y=0
    spots.add(FlSpot(0, 200));

    // Add a point slightly ahead to create straight line to first value
    if (_buffer[0] != 0) {
      spots.add(FlSpot(0.2, _buffer[0]));
    }

    // Add the actual data points
    for (int i = 0; i < size; i++) {
      double x = i * (10 / size); // Distribute points evenly across x-axis
      double y = _buffer[i];

      // Only add non-zero values or values after we've seen a non-zero value
      if (y != 0 || spots.length > 1) {
        spots.add(FlSpot(x + 0.2, y));
      }
    }
    return spots;
  }
}

class EcgProcessor {
  static const int PACKET_SIZE = 6;
  final List<int> buffer = List.filled(PACKET_SIZE, 0);

  List<double> processData(List<int> data) {
    List<double> values = [];

    for (int i = 0; i < data.length; i++) {
      print(' data : ${data[i]}');
      buffer[i % PACKET_SIZE] = data[i];

      // Check for complete packet with 0xFF header
      if (i % PACKET_SIZE == PACKET_SIZE - 1 && buffer[0] == 0xFF) {
        // Extract values using bit manipulation
        int value1 = ((buffer[1] << 2) | (buffer[2] >> 6)) & 0x3FF;
        int value2 = ((buffer[2] << 4) | (buffer[3] >> 4)) & 0x3FF;
        int value3 = ((buffer[3] << 6) | (buffer[4] >> 2)) & 0x3FF;
        int value4 = ((buffer[4] << 8) | buffer[5]) & 0x3FF;

        // Scale values to match your Y-axis range (100-800)
        values.add(scaleValue(value1));
        values.add(scaleValue(value2));
        values.add(scaleValue(value3));
        values.add(scaleValue(value4));
      }
    }
    return values;
  }

  double scaleValue(int value) {
    // Scale 10-bit value (0-1023) to your chart range (100-800)
    return 100 + (value * 700 / 1023);
  }
}
