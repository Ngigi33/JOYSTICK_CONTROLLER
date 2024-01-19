import 'package:remote_controller/homepage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:remote_controller/controlpage.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// This sample app shows an app with two screens.
///
/// The first route '/' is mapped to HomeScreen], and the second route
/// '/details' is mapped to DetailsScreen].
///
/// The buttons use context.go() to navigate to each destination. On mobile
/// devices, each destination is deep-linkable and on the web, can be navigated
/// to using the address bar.

/// The route configuration.
final GoRouter _router = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        //BluetoothDevice btDevice = state.extra as BluetoothDevice;
        return const Homepage();
      },
      routes: <RouteBase>[
        GoRoute(
          name: 'controller',
          path: 'controller',
          builder: (BuildContext context, GoRouterState state) {
            BluetoothDevice btDevice = state.extra as BluetoothDevice;
            return ControlPage(
              device: btDevice,
            );
          },
        ),
      ],
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}
