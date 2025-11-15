import 'dart:convert';
import 'dart:typed_data';

import 'package:ecg_arduino/app/extensions.dart';
import 'package:ecg_arduino/components/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:provider/provider.dart';

import '../app/constants.dart';
import '../components/custom_appbar.dart';
import '../provider/BlueProvider.dart';

class BluetoothScreen extends StatefulWidget {
  const BluetoothScreen({super.key});

  @override
  State<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  late BlueProvider _blueProvider;
  String wifiId = "", wifiPswd = "";
  int timeInterval = 10000;

  @override
  void initState() {
    super.initState();

    _blueProvider = context.read<BlueProvider>();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      getDeviceData();
    });
  }

  void getDeviceData() async {
    _blueProvider.onDataReceived.listen(_handleBluetoothData);

    if (!_blueProvider.isConnected) {
      _blueProvider.startDiscovery();
    } else {
      _blueProvider.sendData(jsonEncode({"command": "GET_DEVICE_PROPERTIES"}));
    }
  }

  void setTimeInterval(int value) async {
    context.showLoading();
    await _blueProvider.sendData(jsonEncode({"time_interval": value}));

    if (!mounted) return;
    context.hideLoading();

    setState(() {
      timeInterval = value;
    });

    context.showMessage("Configure successfully");
  }

  void connectToDevice(BluetoothDevice device) async {
    if (device.name == 'AYT-22') {
      context.showLoading();
      await _blueProvider.connectToDevice(device);

      if (!mounted) return;
      context.hideLoading();

      _blueProvider.sendData(jsonEncode({"command": "GET_DEVICE_PROPERTIES"}));

      // Navigator.pushAndRemoveUntil(
      //     context,
      //     MaterialPageRoute(
      //         builder: (context) =>
      //             EcgScreen(ecgStream: _blueProvider.onDataReceived)),
      //     (route) => false);
    } else {
      print('Device not matched');
      context.hideLoading();
    }
  }

  void _handleBluetoothData(Uint8List data) {
    if (!mounted) return;

    try {
      final String jsonString = utf8.decode(data);
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);

      if (jsonData.containsKey("wifi_id")) {
        wifiId = jsonData["wifi_id"];
      }

      if (jsonData.containsKey("wifi_password")) {
        wifiPswd = jsonData["wifi_password"];
      }

      if (jsonData.containsKey("time_interval")) {
        timeInterval = jsonData["time_interval"];
      }

      setState(() {});
    } catch (err) {
      print(err);
    }
  }

  @override
  void dispose() {
    super.dispose();
    _blueProvider.stopDiscovery();
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BlueProvider>(builder: (context, listener, _) {
      return Scaffold(
        appBar: CustomAppbar(
          title: const Text("Bluetooth"),
          actions: [
            if (listener.bluetoothState == BluetoothState.STATE_ON &&
                !listener.isDiscovering &&
                !listener.isConnected)
              IconButton(
                onPressed: () => _blueProvider.startDiscovery(),
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
        body: Builder(
          builder: (context) {
            if (listener.bluetoothState == BluetoothState.STATE_OFF) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Bluetooth is currently turned off. To use Bluetooth features, please enable it by tapping the button below.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: defaultPadding * 2),
                    SizedBox(
                      width: 200,
                      child: CustomButton(
                        text: "Turn Bluetooth On",
                        onPressed: () => _blueProvider.enableBluetooth(),
                      ),
                    ),
                    const SizedBox(height: defaultPadding * 2),
                  ],
                ),
              );
            }

            if (listener.isConnected) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    ListTile(
                      minLeadingWidth: 0,
                      leading: const Icon(Icons.bluetooth_connected),
                      title: const Text(
                        "Device connected",
                        style: TextStyle(color: secondaryColor, fontSize: 14),
                      ),
                      subtitle: const Text(
                        "Bluetooth is connected to your device",
                        style:
                            TextStyle(color: Color(0xff382721), fontSize: 12),
                      ),
                      trailing: TextButton(
                        onPressed: () => _blueProvider.disconnect(),
                        child: const Text("Disconnect"),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      minLeadingWidth: 0,
                      leading: const Icon(Icons.wifi_lock),
                      title: const Text(
                        "Configure device Wi-Fi",
                        style: TextStyle(color: secondaryColor, fontSize: 14),
                      ),
                      subtitle: Text(
                        wifiId.isNotEmpty
                            ? "Device configured to $wifiId"
                            : "Set up Wi-Fi to send data online",
                        style: const TextStyle(
                          color: Color(0xff382721),
                          fontSize: 12,
                        ),
                      ),
                      trailing: TextButton(
                        onPressed: () {
                          // Navigator.push(
                          //   context,
                          //   MaterialPageRoute(
                          //     builder: (context) => const WifiConfigScreen(),
                          //   ),
                          // );
                        },
                        child: const Text("Configure"),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      minLeadingWidth: 0,
                      leading: const Icon(Icons.timelapse),
                      title: const Text(
                        "Configure Time Interval",
                        style: TextStyle(color: secondaryColor, fontSize: 14),
                      ),
                      subtitle: Text(
                        "Interval set to ${timeInterval ~/ 1000} sec",
                        style: const TextStyle(
                          color: Color(0xff382721),
                          fontSize: 12,
                        ),
                      ),
                      trailing: PopupMenuButton<int>(
                        onSelected: setTimeInterval,
                        itemBuilder: (context) => defaultIntervals.map(
                          (item) {
                            return PopupMenuItem<int>(
                              value: item,
                              child: Text(
                                "${item ~/ 1000} sec",
                                style: const TextStyle(color: Colors.white),
                              ),
                            );
                          },
                        ).toList(),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            "Change",
                            style: TextStyle(color: buttonColor),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            if (!listener.isDiscovering && listener.devices.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(8.0),
                child: Center(
                  child: Text(
                    "No devices available",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              child: Column(
                children: [
                  Visibility(
                    visible: listener.isDiscovering,
                    child: const LinearProgressIndicator(),
                  ),
                  ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(8),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemCount: listener.devices.length,
                    itemBuilder: (context, index) {
                      return Container(
                        decoration: BoxDecoration(
                          color: secondaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          minLeadingWidth: 30,
                          leading:
                              const Icon(Icons.devices, color: primaryColor),
                          visualDensity:
                              const VisualDensity(horizontal: -1, vertical: -1),
                          title: Text(
                            listener.devices[index].name ?? "Unknown device",
                            style: const TextStyle(
                              color: primaryColor,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            listener.devices[index].address,
                            style: const TextStyle(
                              color: primaryColor,
                              fontSize: 12,
                            ),
                          ),
                          trailing: TextButton(
                            onPressed: () =>
                                connectToDevice(listener.devices[index]),
                            child: const Text("Connect"),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      );
    });
  }
}
