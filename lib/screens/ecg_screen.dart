// ignore_for_file: prefer_const_constructors, library_private_types_in_public_api

import 'dart:async';
import 'package:ecg_arduino/provider/BlueProvider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app/constants.dart';

class EcgScreen extends StatefulWidget {
  const EcgScreen({super.key});

  @override
  _EcgScreenState createState() => _EcgScreenState();
}

class _EcgScreenState extends State<EcgScreen> {
  final CircularBuffer ecgData = CircularBuffer(1800);
  double currentX = 0;
//  static const int maxDataPoints = 600; // 3 seconds of data at 200Hz
  static const double xAxisDuration = 9.0; // 3 seconds window
  static const double minY = -200;
  static const double maxY = 400;
  bool isReading = false;
  late BlueProvider _blueProvider;
  StreamSubscription? _dataSubscription;
  final EcgProcessor _processor = EcgProcessor();
  Timer? _updateTimer;

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
    });

    // Send command to start ECG readings
    _blueProvider.sendData('5');

    // Setup data listener
    _dataSubscription = _blueProvider.onDataReceived.listen((data) {
      List<double> processedValues = _processor.processData(data);
      for (double value in processedValues) {
        _addDataPoint(value);
      }
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

    // Reset chart to empty state
    _stopChartUpdate();
  }

  void _startChartUpdate() {
    _updateTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
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
            LineChartData(
              minX: 0,
              maxX: xAxisDuration,
              minY: minY,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                horizontalInterval: 100,
                verticalInterval: 1,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey[300],
                    strokeWidth: 1,
                  );
                },
                getDrawingVerticalLine: (value) {
                  return FlLine(
                    color: Colors.grey[300],
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 0.5,
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
                  spots: ecgData.getSpots(),
                  isCurved: false,
                  color: Colors.blue,
                  barWidth: 2,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(show: false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CircularBuffer {
  final int size;
  final List<double> _buffer;
  int _index = 0;

  CircularBuffer(this.size) : _buffer = List.filled(size, 0);

  void add(double value) {
    _buffer[_index] = value;
    _index = (_index + 1) % size;
  }

  List<FlSpot> getSpots() {
    List<FlSpot> spots = [];
    for (int i = 0; i < size; i++) {
      double x = i * 0.5; // Adjust x-axis range
      double y = _buffer[(_index + i) % size];
      if (i > 0 && spots.isNotEmpty) {
        // Ensure stability at 0 when there is no value
        y = y != 0 ? y : spots.last.y;
      }
      spots.add(FlSpot(x, y));
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
