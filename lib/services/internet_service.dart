import 'dart:async';
import 'dart:developer';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class InternetService {
  static InternetService? _instance;
  static InternetService get instance {
    return _instance ??= InternetService._();
  }

  InternetService._();
  GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  late StreamSubscription<ConnectivityResult> streamSubscription;

  late bool connected;

  Future init() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      showInternetSnakBar();
      connected = false;
    } else {
      connected = true;
    }
    streamSubscription = Connectivity().onConnectivityChanged.listen((event) {
      log("internet: ${event.name}");
      if (event == ConnectivityResult.none) {
        connected = false;
        showInternetSnakBar();
      } else {
        connected = true;
        hidInternetSnakBar();
      }
    });
  }

  dispose() {
    streamSubscription.cancel();
  }

  void showInternetSnakBar() {
    SnackBar snackBar = const SnackBar(
      content: Row(
        children: [
          Icon(
            Icons.wifi_off,
            color: Colors.white,
          ),
          SizedBox(width: 10),
          Text(
            "No internet connected",
          ),
        ],
      ),
      duration: Duration(days: 1),
    );
    if (navigatorKey.currentContext != null) {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(snackBar);
    }
  }

  void hidInternetSnakBar() {
    if (navigatorKey.currentContext != null) {
      ScaffoldMessenger.of(navigatorKey.currentContext!).hideCurrentSnackBar();
    }
  }
}
