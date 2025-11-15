// ignore_for_file: prefer_final_fields, avoid_print

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

class BlueProvider with ChangeNotifier {
  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;

  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  BluetoothConnection? _connection;
  bool _isDiscovering = false;
  bool _isConnected = false;
  List<BluetoothDevice> _devices = [];
  final StreamController<Uint8List> _dataStreamController =
      StreamController<Uint8List>.broadcast();

  List<int> _ecgvalues = [];

  BluetoothState get bluetoothState => _bluetoothState;
  bool get isDiscovering => _isDiscovering;
  bool get isConnected => _isConnected;
  List<BluetoothDevice> get devices => _devices;
  Stream<Uint8List> get onDataReceived => _dataStreamController.stream;
  List<int> get ecgvalues => _ecgvalues;

  BlueProvider() {
    initialize();
  }

  Future<void> initialize() async {
    _bluetoothState = await _bluetooth.state;
    print(_bluetoothState);
    notifyListeners();

    _bluetooth.onStateChanged().listen((state) {
      print("state: ${state}");
      _bluetoothState = state;
      notifyListeners();

      if (_bluetoothState == BluetoothState.STATE_OFF) {
        _onConnectionClosed();
      }
    });
  }

  Future<void> enableBluetooth() async {
    await checkPermissions();
    await _bluetooth.requestEnable();
  }

  Future<void> checkPermissions() async {
    var statuses = await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();

    if (statuses[Permission.bluetooth]!.isDenied ||
        statuses[Permission.bluetoothConnect]!.isDenied ||
        statuses[Permission.bluetoothScan]!.isDenied) {
      print("Necessary permissions denied.");
      return;
    }
    print("All necessary permissions granted.");
  }

  void startDiscovery() async {
    if (_isDiscovering) {
      print("Discovery already in progress");
      return;
    }

    devices.clear();
    notifyListeners();

    await checkPermissions();

    print("Starting device discovery...");
    _isDiscovering = true;

    _bluetooth.startDiscovery().listen((r) {
      devices.add(r.device);
      notifyListeners();
    }).onDone(() {
      _isDiscovering = false;
      notifyListeners();
    });
  }

  void stopDiscovery() async {
    if (!_isDiscovering) return;

    _bluetooth.cancelDiscovery();
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      _isConnected = true;
      notifyListeners();

      _connection?.input?.listen(_onDataReceived).onDone(() {
        _onConnectionClosed();
      });
    } catch (error) {
      print(error);

      _isConnected = false;
      notifyListeners();
    }
  }

  Future<void> sendData(String data) async {
    try {
      if (_isConnected) {
        // utf8.encode("START")
        _connection?.output.add(Uint8List.fromList(data.codeUnits));
        await _connection?.output.allSent;

        print(data);
      }
    } catch (error) {
      print(error);
    }
  }

  void sendRaw(List<int> bytes) async {
    if (_isConnected) {
      final data = Uint8List.fromList(bytes);
      print("Sending RAW: $data");
      _connection?.output.add(data);
      await _connection?.output.allSent;
    }
  }

  void _onDataReceived(Uint8List data) {
    try {
      //print('Received data: ${String.fromCharCodes(data)}');
      // _receivedData = data;
      // notifyListeners();

      // if (data.isNotEmpty && data[0] == 0xFF) {
      print("recieved data: ${Uint8List.fromList(data)}");
      _dataStreamController.add(Uint8List.fromList(data));
      // }
    } catch (error) {
      print('Error processing data: $error');
    }
  }

  void _onConnectionClosed() {
    _isConnected = false;
    _isDiscovering = false;
    _connection = null;
    _devices.clear();

    notifyListeners();
    print('Disconnected');
  }

  Future<void> disconnect() async {
    if (_isConnected) {
      await _connection?.close();
      _onConnectionClosed();
    }
  }
}
