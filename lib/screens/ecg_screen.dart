// import 'dart:typed_data';

// import 'package:fl_chart/fl_chart.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';

// import '../provider/BlueProvider.dart';

// class EcgScreen extends StatefulWidget {
//   const EcgScreen({super.key});

//   @override
//   State<EcgScreen> createState() => _EcgScreenState();
// }

// class _EcgScreenState extends State<EcgScreen> {
//   final List<FlSpot> _points = [];
//   double x = 0;
//   final int maxSamples = 600;
//   Stream<Uint8List>? _ecgStream;
//   late BlueProvider blueProvider;

//   @override
//   void initState() {
//     super.initState();
//     SystemChrome.setPreferredOrientations([
//       DeviceOrientation.landscapeLeft,
//       DeviceOrientation.landscapeRight,
//     ]);
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       blueProvider = Provider.of<BlueProvider>(context, listen: false);
//       _ecgStream = blueProvider.onDataReceived;
//       _listenToEcg();
//     });
//   }

//   void _listenToEcg() {
//     _ecgStream?.listen((data) {
//       // Convert ASCII packets to text
//       final text = String.fromCharCodes(data);
//       if (text.startsWith("on") ||
//           text.contains("!") ||
//           text.contains("?") ||
//           text.contains(";")) {
//         print("Non-ECG: $text");
//         return;
//       }

//       // Parse 6-byte ECG sample
//       final sample = _parseEcgPacket(data);
//       if (sample == null) return;

//       // Add to graph
//       if (_points.length > maxSamples) _points.removeAt(0);
//       _points.add(FlSpot(x, sample.toDouble()));
//       x += 1;

//       setState(() {});
//     });
//   }

//   int? _parseEcgPacket(Uint8List b) {
//     if (b.length != 6) return null;
//     if (b[0] != 0xFF) return null;

//     int value = (b[1] << 2) | ((b[2] & 0xC0) >> 6);

//     return value;
//   }

//   @override
//   void dispose() {
//     super.dispose();
//     SystemChrome.setPreferredOrientations([
//       DeviceOrientation.portraitUp,
//       DeviceOrientation.portraitDown,
//     ]);
//   }

//   @override
//   Widget build(BuildContext context) {
//     final isConnected = context.watch<BlueProvider>().isConnected;

//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         title: const Text("ECG Monitor"),
//         backgroundColor: Colors.green.shade700,
//         actions: [
//           IconButton(
//             onPressed: () {
//               blueProvider.sendData('53'); // '5' → Start ECG
//             },
//             icon: const Icon(Icons.play_arrow),
//           ),
//           IconButton(
//             onPressed: () {
//               blueProvider.disconnect();
//             },
//             icon: const Icon(Icons.stop, color: Colors.red),
//           ),
//         ],
//       ),
//       body: Center(
//         child: isConnected
//             ? LineChart(
//                 LineChartData(
//                   minY: 0,
//                   maxY: 1023,
//                   minX: x - maxSamples,
//                   maxX: x,
//                   lineBarsData: [
//                     LineChartBarData(
//                       spots: _points,
//                       isCurved: true,
//                       color: Colors.greenAccent,
//                       barWidth: 2,
//                       dotData: FlDotData(show: false),
//                     ),
//                   ],
//                   titlesData: FlTitlesData(show: false),
//                   gridData: FlGridData(show: false),
//                   borderData: FlBorderData(show: false),
//                 ),
//               )
//             : const Text("Device not connected",
//                 style: TextStyle(color: Colors.white, fontSize: 16)),
//       ),
//     );
//   }
// }
