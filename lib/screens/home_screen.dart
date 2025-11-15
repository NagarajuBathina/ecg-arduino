import 'package:ecg_arduino/components/custom_appbar.dart';
import 'package:ecg_arduino/provider/BlueProvider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'bluetooth_screen.dart';
import 'dummy_ecg_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String _btnText = 'Bluetooth';

  @override
  Widget build(BuildContext context) {
    final bool isConnected =
        Provider.of<BlueProvider>(context, listen: false).isConnected;
    return Scaffold(
      appBar: CustomAppbar(
        title: const Text('ECG Arduino'),
        actions: [
          if (isConnected)
            TextButton(
                onPressed: () {
                  Provider.of<BlueProvider>(context, listen: false)
                      .disconnect();
                },
                child: Text(!isConnected ? 'Connected' : 'Disconnect'))
        ],
      ),
      body: SafeArea(
          child: Center(
        child: Column(
          children: [
            ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BluetoothScreen(),
                    ),
                  );
                },
                child: Text(_btnText)),
            ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EcgScreen(),
                    ),
                  );
                },
                child: const Text('ECG'))
          ],
        ),
      )),
    );
  }
}
