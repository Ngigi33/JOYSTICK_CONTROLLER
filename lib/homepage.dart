import 'dart:io';
import 'dart:async';

import 'package:remote_controller/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:remote_controller/utils/snackbar.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../utils/extra.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() {
    return _HomepageState();
  }
}

class _HomepageState extends State<Homepage> with WidgetsBindingObserver {
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  late StreamSubscription<BluetoothAdapterState> _adapterStateStateSubscription;

  List<BluetoothDevice> _systemDevices = [];
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late StreamSubscription<bool> _isScanningSubscription;

  BluetoothDevice? targetDevice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    bleInit();
  }

  @override
  void dispose() {
    _scanResultsSubscription.cancel();
    _isScanningSubscription.cancel();
    _adapterStateStateSubscription.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_isScanning && targetDevice == null) {
          onScanning();
        }
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.paused:
        onStopScanning();
        break;
      case AppLifecycleState.detached:
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  void bleInit() {
    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      _scanResults = results;
      findTargetDevice();
      setState(() {});
    }, onError: (e) {
      Snackbar.show(ABC.b, prettyException("Scan Error:", e), success: false);
    });

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      _isScanning = state;
      setState(() {});
    });

    _adapterStateStateSubscription =
        FlutterBluePlus.adapterState.listen((state) {
      _adapterState = state;
      setState(() {});
    });

    FlutterBluePlus.systemDevices.then((devices) {
      _systemDevices = devices;
      setState(() {});
    });

    onScanning();
  }

  Future onScanning() async {
    try {
      int divisor = Platform.isAndroid ? 8 : 1;
      await FlutterBluePlus.startScan(
          timeout: null, continuousUpdates: true, continuousDivisor: divisor);
    } catch (e) {
      Snackbar.show(ABC.b, prettyException("Start Scan Error:", e),
          success: false);
    }
    setState(() {});
  }

  Future onStopScanning() async {
    try {
      FlutterBluePlus.stopScan();
    } catch (e) {
      Snackbar.show(ABC.b, prettyException("Stop Scan Error:", e),
          success: false);
    }
  }

  void findTargetDevice() async {
    final index = _scanResults
        .indexWhere((item) => item.device.remoteId.str == DEVICE_MAC_ID);
    if (index >= 0) {
      targetDevice = _scanResults[index].device;

      onStopScanning();

      await targetDevice?.connectAndUpdateStream().catchError((e) async {
        await targetDevice?.disconnectAndUpdateStream();
        onScanning();
      });

      if (targetDevice!.isConnected) {
        await Future.delayed(const Duration(seconds: 1));

        if (!context.mounted) return;
        var result = await context.pushNamed(
          'controller',
          extra: targetDevice,
        );

        if (result != null && result == true) {
          onScanning();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _adapterState == BluetoothAdapterState.on
          ? Stack(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Lottie.asset(
                    'assets/Connecting.json',
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Lottie.asset('assets/robot_scanning.json'),
                ),

                // Align(
                //   alignment: Alignment.centerRight,
                //   child: Lottie.asset('assets/Plugs_connecting.json',height: 150
                //   ),
                // )
              ],
            )
          : Column(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child:
                      Lottie.asset('assets/bluetooth_symbol.json', height: 300),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Lottie.asset('assets/Turn_on.json', height: 80),
                )
              ],
            ),
    );
  }
}
