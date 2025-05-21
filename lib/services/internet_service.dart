import 'dart:async';
import 'dart:developer';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class InternetService {
  InternetService._();
  static final InternetService instance = InternetService._();

  /// Use this in your `MaterialApp(navigatorKey: …)` so the snackbar can show.
  final navigatorKey = GlobalKey<NavigatorState>();

  /// 👇  v6 emits *lists* of results, not a single enum
  late StreamSubscription<List<ConnectivityResult>> _subscription;

  // Observable connectivity state
  final RxBool _isConnected = true.obs;
  bool get connected => _isConnected.value;

  // Stream controller for connectivity changes
  final _connectivityController = StreamController<bool>.broadcast();
  Stream<bool> get connectivityStream => _connectivityController.stream;

  Future<void> init() async {
    // ----- first, check the current state -----------------------------------
    final initial = await Connectivity().checkConnectivity();
    _isConnected.value = !initial.contains(ConnectivityResult.none);
    if (!_isConnected.value) _showNoInternetSnackBar();

    // Emit initial state to stream
    _connectivityController.add(_isConnected.value);

    // ----- then, listen for changes -----------------------------------------
    _subscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      log('internet: ${results.map((e) => e.name).join(", ")}');

      final nowConnected = !results.contains(ConnectivityResult.none);
      if (nowConnected != _isConnected.value) {
        _isConnected.value = nowConnected;

        // Emit to stream
        _connectivityController.add(_isConnected.value);

        // Update UI
        _isConnected.value ? _hideSnackBar() : _showNoInternetSnackBar();
      }
    });
  }

  void dispose() {
    _subscription.cancel();
    _connectivityController.close();
  }

  /// Check current connectivity status
  Future<bool> checkConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final isConnected = !results.contains(ConnectivityResult.none);

      // Update state if different
      if (isConnected != _isConnected.value) {
        _isConnected.value = isConnected;
        _connectivityController.add(isConnected);
      }

      return isConnected;
    } catch (e) {
      log('Error checking connectivity: $e');
      return _isConnected.value; // Return last known state
    }
  }

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

    // Try using Get.context first for GetX compatibility
    final ctx = Get.context ?? navigatorKey.currentContext;
    if (ctx != null) ScaffoldMessenger.of(ctx).showSnackBar(snackBar);
  }

  void _hideSnackBar() {
    // Try using Get.context first for GetX compatibility
    final ctx = Get.context ?? navigatorKey.currentContext;
    if (ctx != null) ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
  }
}
