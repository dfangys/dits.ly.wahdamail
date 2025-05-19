import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';

/// Controller responsible for managing background tasks and operations
class BackgroundTaskController extends GetxController {
  final Logger logger = Logger();

  // Operation queue for background tasks
  final _operationQueue = <Future Function()>[];
  bool _isProcessingQueue = false;

  // For tracking operation status
  final RxInt pendingOperations = 0.obs;
  final RxBool isProcessing = false.obs;

  @override
  void onInit() {
    // Start processing the operation queue
    _startQueueProcessing();
    super.onInit();
  }

  /// Process operations in background to prevent UI blocking
  void _startQueueProcessing() {
    if (_isProcessingQueue) return;

    _isProcessingQueue = true;
    isProcessing(true);

    Future.microtask(() async {
      while (_operationQueue.isNotEmpty) {
        final operation = _operationQueue.removeAt(0);
        pendingOperations.value = _operationQueue.length;

        try {
          await operation();
        } catch (e) {
          logger.e('Error processing queued operation: $e');
        }

        // Yield to UI thread
        await Future.delayed(Duration.zero);
      }

      _isProcessingQueue = false;
      isProcessing(false);
      pendingOperations.value = 0;
    });
  }

  /// Add operation to queue and start processing
  void queueOperation(Future Function() operation) {
    _operationQueue.add(operation);
    pendingOperations.value = _operationQueue.length;

    if (!_isProcessingQueue) {
      _startQueueProcessing();
    }
  }

  /// Add multiple operations to queue
  void queueOperations(List<Future Function()> operations) {
    _operationQueue.addAll(operations);
    pendingOperations.value = _operationQueue.length;

    if (!_isProcessingQueue) {
      _startQueueProcessing();
    }
  }

  /// Clear all pending operations
  void clearQueue() {
    _operationQueue.clear();
    pendingOperations.value = 0;
  }

  /// Execute operation with retry logic
  Future<T?> executeWithRetry<T>(
      Future<T> Function() operation, {
        int maxRetries = 3,
        Duration retryDelay = const Duration(seconds: 1),
      }) async {
    int attempts = 0;

    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        logger.e('Operation failed (attempt $attempts/$maxRetries): $e');

        if (attempts >= maxRetries) {
          // Show error message on final failure
          Get.showSnackbar(
            GetSnackBar(
              message: 'Operation failed after $maxRetries attempts: ${e.toString()}',
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
          return null;
        }

        // Wait before retrying
        await Future.delayed(retryDelay * attempts);
      }
    }

    return null;
  }

  /// Execute operation with timeout
  Future<T?> executeWithTimeout<T>(
      Future<T> Function() operation,
      Duration timeout, {
        T? defaultValue,
      }) async {
    try {
      return await operation().timeout(timeout);
    } on TimeoutException {
      logger.w('Operation timed out after ${timeout.inSeconds} seconds');
      return defaultValue;
    } catch (e) {
      logger.e('Operation failed: $e');
      return defaultValue;
    }
  }
}
