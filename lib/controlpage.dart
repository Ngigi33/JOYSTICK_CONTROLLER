import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:go_router/go_router.dart';
import 'package:remote_controller/utils/util.dart';
import 'package:kdgaugeview/kdgaugeview.dart';
import 'package:lottie/lottie.dart';
import 'package:remote_controller/utils/extra.dart';
import 'dart:async';
import 'dart:io';
import 'package:remote_controller/constants.dart';
import 'package:flutter/services.dart';
import 'package:remote_controller/utils/extra.dart';
import 'package:remote_controller/utils/snackbar.dart';

class ControlPage extends StatefulWidget {
  final BluetoothDevice device;
  const ControlPage({Key? key, required this.device}) : super(key: key);

  @override
  State<ControlPage> createState() {
    return _ControlPageState();
  }
}

class _ControlPageState extends State<ControlPage> {
  int? _rssi;
  int? _mtuSize;
  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;
  List<BluetoothService> _services = [];
  bool _isDiscoveringServices = false;
  bool _isConnecting = false;
  bool _isDisconnecting = false;

  late StreamSubscription<BluetoothConnectionState>
      _connectionStateSubscription;
  late StreamSubscription<bool> _isConnectingSubscription;
  late StreamSubscription<bool> _isDisconnectingSubscription;
  late StreamSubscription<int> _mtuSubscription;

  List<int> _value = [];
  late StreamSubscription<List<int>> _lastValueSubscription;

  BluetoothCharacteristic? _characteristicTX;

  bool _isSendingDC = false;
  bool _isSendingSERVO = false;
  double _rowWidth = 0;
  int _preDC = 0;
  int _preServo = 0;
  final speedNotifier = ValueNotifier<double>(10);
  final key = GlobalKey<KdGaugeViewState>();
  bool _anim = false;

  @override
  void initState() {
    super.initState();

    _connectionStateSubscription =
        widget.device.connectionState.listen((state) async {
      _connectionState = state;
      if (state == BluetoothConnectionState.connected) {
        _services = [];
      }
      if (state == BluetoothConnectionState.connected && _rssi == null) {
        _rssi = await widget.device.readRssi();
      }

      if (state == BluetoothConnectionState.disconnected) {}
    });

    _mtuSubscription = widget.device.mtu.listen((value) {
      _mtuSize = value;
      if (mounted) {
        setState(() {});
      }
    });

    _isConnectingSubscription = widget.device.isConnecting.listen((value) {
      _isConnecting = value;
      setState(() {});
    });

    _isDisconnectingSubscription =
        widget.device.isDisconnecting.listen((value) {
      _isDisconnecting = value;
      setState(() {});
    });
    onDiscoverServices();
    onRequestMtuPressed();
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    _mtuSubscription.cancel();
    _isConnectingSubscription.cancel();
    _isDisconnectingSubscription.cancel();
    _lastValueSubscription.cancel();
    super.dispose();
  }

  bool get isConnected {
    return _connectionState == BluetoothConnectionState.connected;
  }

  Future onConnect() async {
    try {
      await widget.device.connectAndUpdateStream();
    } catch (e) {
      if (e is FlutterBluePlusException &&
          e.code == FbpErrorCode.connectionCanceled.index) {
      } else {
        print("Connect Error:${e.toString()}");
      }
    }
  }

  Future onCancel() async {
    try {
      await widget.device.disconnectAndUpdateStream(queue: false);
    } catch (e) {
      print('Cancel Error: ${e.toString()}');
    }
  }

  Future onDisconnect() async {
    try {
      await widget.device.disconnectAndUpdateStream();
    } catch (e) {
      print("Disconnect Error:${e.toString()}");
    }
  }

  Future onDiscoverServices() async {
    _isDiscoveringServices = true;
    try {
      // while(_services.isEmpty){
      //   _services= await widget.device.discoverServices()
      //   .timeout(Duration(seconds: 10),onTimeout: () => <BluetoothService>[],);
      // }

      //   widget.device.discoverServices().then((s) => _services=s);
      //   Future.delayed(Duration(milliseconds: 100), (){
      //   while (_services.isEmpty) {

      //    widget.device.discoverServices();
      //     print("Services empty");
      //   }
      // });

      _services = await widget.device.discoverServices();

      final targetServiceUUID = _services.singleWhere(
          (item) => item.serviceUuid.str.toUpperCase() == SERVICE_UUID);
      print("Service is not empty");

      final targetCharacterUUID = targetServiceUUID.characteristics.singleWhere(
          (item) =>
              item.characteristicUuid.str.toUpperCase() ==
              CHARACTERISTIC_UUID_RX);

      await targetCharacterUUID.setNotifyValue(true);

      _lastValueSubscription =
          targetCharacterUUID.lastValueStream.listen((value) {
        _value = value;
        setState(() {});
      });

      _characteristicTX = targetServiceUUID.characteristics.singleWhere(
          (item) =>
              item.characteristicUuid.str.toUpperCase() ==
              CHARACTERISTIC_UUID_TX);
    } catch (e) {
      print("Discover Services Error:${e.toString()}");
    }
    _isDiscoveringServices = false;
  }

  Future onRequestMtuPressed() async {
    try {
      await widget.device.requestMtu(223, predelay: 0);
      Snackbar.show(ABC.c, "Request Mtu: Success", success: true);
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Change Mtu Error:", e),
          success: false);
    }
  }

  void backToHome(bool needToReConnect) {
    onDisconnect();
    context.pop(needToReConnect);
  }

  void writeBLE(int cmd, int data) async {
    if (!isConnected) {
      backToHome(true);
      return;
    }

    if (cmd == CMD_DC && _isSendingDC) {
      _isSendingDC = false;
      await _characteristicTX?.write([cmd, data], timeout: 1);
      print("Command=${cmd.toString()}");
      print("Value= ${data.toString()}");
      _isSendingDC = true;
    } else if (cmd == CMD_SERVO && _isSendingSERVO) {
      _isSendingSERVO = false;
      String msg = cmd.toString();
      await _characteristicTX?.write([cmd, data], timeout: 1);
      print("Command=${cmd.toString()}");
      print("Value= ${data.toString()}");
      _isSendingSERVO = true;
    }

    if (cmd == CMD_DC) {
      _preDC = data;
    } else if (cmd == CMD_SERVO) {
      _preServo = data;
    }
  }

  void updateSpeedometer(int rawValue) {
    //print(rawValue);
    double base = rawValue - 127;
    double gaugeData=0;
    int remapData=0;

    if (base <= 0) {
      gaugeData=base.remap(-127, 0, 150, 0);
      //_anim = true;
    } else {
      gaugeData=base.remap(0, 127, 0, 150);
      //_anim = true;
    }

    key.currentState!.updateSpeed(gaugeData.toDouble());
    speedNotifier.value = gaugeData.toDouble();
  }

  void prepareSendingData(int cmd, double data) {
    int remappingInt = 0;

    if (cmd == CMD_DC) {
      double remapping = data.remap(-1.00, 1.00, 255, 0);
      remappingInt = remapping.toInt();
      updateSpeedometer(remappingInt);

      if ((remappingInt - _preDC).abs() < DATA_GAP) {
        return;
      }
    } else if (cmd == CMD_SERVO) {
      double remapping = data.remap(-1.00, 1.00, 0, 255);
      remappingInt = remapping.toInt();
      if ((remappingInt - _preServo).abs() < DATA_GAP) {
        return;
      }
    }
    setState(() {});
    writeBLE(cmd, remappingInt);
  }

  @override
  void didChangeDependencies() {
    _rowWidth = MediaQuery.of(context).size.width / 2;
    super.didChangeDependencies();
  }

  void _getOutOfApp() {
    onDisconnect();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (Platform.isIOS) {
        try {
          exit(0);
        } catch (e) {
          SystemNavigator.pop();
        }
      } else {
        try {
          SystemNavigator.pop();
        } catch (e) {
          exit(0);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {},
      child: Scaffold(
        backgroundColor: Color.fromARGB(255, 221, 190, 66),
        body: SafeArea(
            child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child:
                  Lottie.asset('assets/suv.json', width: 200, animate: _anim),
            ),
            Center(
              child: Container(
                width: 360,
                height: 360,
                padding: const EdgeInsets.all(10),
                child: ValueListenableBuilder(
                    valueListenable: speedNotifier,
                    builder: (context, value, child) {
                      return KdGaugeView(
                        key: key,
                        minSpeed: 0,
                        maxSpeed: 150,
                        unitOfMeasurement: 'KM/HR',
                        animate: true,
                        alertSpeedArray: const [40, 75, 110],
                        speed: 0,
                        speedTextStyle: TextStyle(
                            fontSize: 80,
                            fontWeight: FontWeight.bold,
                            foreground: Paint()..color = Colors.black87),
                        alertColorArray: const [
                          //Colors.orange,
                          Colors.indigo,
                          Colors.green,
                          Colors.red
                        ],
                        duration: const Duration(seconds: 6),
                      );
                    }),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                    width: _rowWidth,
                    height: double.infinity,
                    alignment: Alignment.centerLeft,
                    child: Joystick(
                      mode: JoystickMode.vertical,
                      onStickDragStart: () {
                        _isSendingDC = true;
                        _anim=true;
                      },
                      onStickDragEnd: () {
                        _isSendingDC = false;
                        _anim=false;
                      },
                      listener: (details) {
                        prepareSendingData(CMD_DC, details.y);
                        // print("y=");
                        // print(details.y);
                      },
                    ),
                  ),
                  Container(
                      width: _rowWidth,
                      height: double.infinity,
                      alignment: Alignment.centerRight,
                      child: Joystick(
                        mode: JoystickMode.horizontal,
                        onStickDragStart: () {
                          _isSendingSERVO = true;
                        },
                        onStickDragEnd: () {
                          _isSendingSERVO = false;
                        },
                        listener: (details) {
                          prepareSendingData(CMD_SERVO, details.x);
                          // print("x=");
                          // print( details.x);
                        },
                        //initialJoystickAlignment: const Alignment(0, 0.8),
                      ))
                ],
              ),
            ),
            Positioned(
              top: 1,
              right: 1,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: CloseButton(
                  color: Colors.blueGrey,
                  onPressed: () {
                    showDialog<String>(
                        context: context,
                        builder: (BuildContext context) => AlertDialog(
                              title:
                                  const Text("Do you want to close the app ?"),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, 'Cancel'),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                    onPressed: () => _getOutOfApp(),
                                    child: const Text('Ok'))
                              ],
                            ));
                  },
                ),
              ),
            )
          ],
        )),
      ),
    );
  }
}
