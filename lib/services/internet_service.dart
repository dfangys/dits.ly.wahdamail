import 'dart:async';
import 'dart:developer';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class InternetService {
  InternetService._();
  static final InternetService instance = InternetService._();

  /// Use this in your `MaterialApp(navigatorKey: …)` so the snackbar can show.
  final navigatorKey = GlobalKey<NavigatorState>();

  /// 👇  v6 emits *lists* of results, not a single enum
  late StreamSubscription<List<ConnectivityResult>> _subscription;

  bool connected = true;

  Future<void> init() async {
    // ----- first, check the current state -----------------------------------
    final initial = await Connectivity().checkConnectivity();
    connected = !initial.contains(ConnectivityResult.none);
    if (!connected) _showNoInternetSnackBar();

    // ----- then, listen for changes -----------------------------------------
    _subscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      log('internet: ${results.map((e) => e.name).join(", ")}');

      final nowConnected = !results.contains(ConnectivityResult.none);
      if (nowConnected != connected) {
        connected = nowConnected;
        connected ? _hideSnackBar() : _showNoInternetSnackBar();
      }
    });
  }

  void dispose() => _subscription.cancel();

  // --------------------------------------------------------------------------
  // UI helpers
  // --------------------------------------------------------------------------
  void _showNoInternetSnackBar() {
    const snackBar = SnackBar(
      duration: Duration(days: 1), // stays until we hide it
      content: Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.white),
          SizedBox(width: 10),
          Text('No internet connection'),
        ],
      ),
    );
    final ctx = navigatorKey.currentContext;
    if (ctx != null) ScaffoldMessenger.of(ctx).showSnackBar(snackBar);
  }

  void _hideSnackBar() {
    final ctx = navigatorKey.currentContext;
    if (ctx != null) ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
  }
}
