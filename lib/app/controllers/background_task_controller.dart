import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:wahda_bank/services/bg_service.dart';
import 'package:workmanager/workmanager.dart';
import 'dart:io' show Platform;


/// Controller responsible for managing background tasks and operations
class BackgroundTaskController extends GetxController {
  final Logger logger = Logger();

  // Operation queue with priority support
  final _highPriorityQueue = <Future Function()>[];
  final _normalPriorityQueue = <Future Function()>[];
  final _lowPriorityQueue = <Future Function()>[];
  bool _isProcessingQueue = false;

  // For tracking operation status
  final RxInt pendingOperations = 0.obs;
  final RxBool isProcessing = false.obs;

  // For monitoring task performance
  final Map<String, int> _taskDurations = {};
  final RxMap<String, int> averageTaskDurations = <String, int>{}.obs;

  // For error recovery
  final Map<String, int> _failedTasks = {};
  final RxInt failedTaskCount = 0.obs;

  // For operation coordination
  final _operationLocks = <String, Completer<void>>{};

  @override
  void onInit() {
    super.onInit();
    // delay and then await both calls so their exceptions get caught
    Future.delayed(const Duration(milliseconds: 500), () async {
      await initializeBackgroundTasks();
      await registerPeriodicEmailChecks();
    });
  }

  /// Initialize background tasks
  Future<void> initializeBackgroundTasks() async {
    try {
      await BgService.instance.initialize();
      logger.d("Background tasks initialized");
    } catch (e, st) {
      logger.e("Error initializing background tasks: $e\n$st");
    }
  }



  /// Register periodic email checks
  Future<void> registerPeriodicEmailChecks() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await BgService.instance.registerPeriodicEmailChecks();
        logger.d("Periodic email checks registered");
      } on PlatformException catch (err, st) {
        // <-- use named parameters for error & stackTrace
        logger.w(
          "Workmanager not available on this platform, skipping",
          error: err,
          stackTrace: st,
        );
      } catch (e, st) {
        logger.w(
          "Unexpected error registering periodic checks: $e",
          error: e,
          stackTrace: st,
        );
      }
    } else {
      logger.i("Skipping periodic email checks on non-Android platform");
    }
  }


  /// Process operations in background to prevent UI blocking
  void _startQueueProcessing() {
    if (_isProcessingQueue) return;

    _isProcessingQueue = true;
    isProcessing(true);

    Future.microtask(() async {
      while (_highPriorityQueue.isNotEmpty ||
          _normalPriorityQueue.isNotEmpty ||
          _lowPriorityQueue.isNotEmpty) {
        Future Function()? operation;

        if (_highPriorityQueue.isNotEmpty) {
          operation = _highPriorityQueue.removeAt(0);
        } else if (_normalPriorityQueue.isNotEmpty) {
          operation = _normalPriorityQueue.removeAt(0);
        } else if (_lowPriorityQueue.isNotEmpty) {
          operation = _lowPriorityQueue.removeAt(0);
        }

        pendingOperations.value = _totalPendingOperations;

        if (operation != null) {
          try {
            final taskId = operation.hashCode.toString();
            final startTime = DateTime.now().millisecondsSinceEpoch;

            await operation();

            final endTime = DateTime.now().millisecondsSinceEpoch;
            final duration = endTime - startTime;
            _updateAverageDuration(taskId, duration);

            // Clear failed task record if it exists
            if (_failedTasks.containsKey(taskId)) {
              _failedTasks.remove(taskId);
              failedTaskCount.value = _failedTasks.length;
            }
          } catch (e, stack) {
            final taskId = operation.hashCode.toString();
            logger.e("⛔ Error processing queued operation: $e\n$stack");

            // Track failed task
            _failedTasks[taskId] = (_failedTasks[taskId] ?? 0) + 1;
            failedTaskCount.value = _failedTasks.length;

            // If task has failed multiple times, log more details
            if (_failedTasks[taskId]! > 2) {
              logger.e("Task $taskId has failed ${_failedTasks[taskId]} times");
            }
          }
        }

        // Let UI breathe between operations
        await Future.delayed(const Duration(milliseconds: 10));
      }

      isProcessing(false);
      _isProcessingQueue = false;
    });
  }

  /// Register background task safely
  void safeRegisterBackgroundTask() {
    // Android only – and ONLY after Workmanager.initialize(...)
    if (!kIsWeb && Platform.isAndroid) {
      Workmanager().registerPeriodicTask(
        'syncTask',
        'syncWithServer',
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        backoffPolicy: BackoffPolicy.exponential,
      );
    } else {
      logger.d('Periodic background tasks are not supported on this platform.');
    }
  }

  /// Update average duration for task performance tracking
  void _updateAverageDuration(String taskId, int duration) {
    const weight = 0.5; // exponential moving average weight

    if (_taskDurations.containsKey(taskId)) {
      final oldDuration = _taskDurations[taskId]!;
      final newAvg = (oldDuration * (1 - weight) + duration * weight).round();
      _taskDurations[taskId] = newAvg;
    } else {
      _taskDurations[taskId] = duration;
    }

    averageTaskDurations[taskId] = _taskDurations[taskId]!;
  }

  /// Add operation to queue with priority and start processing
  void queueOperation(Future Function() operation, {Priority priority = Priority.normal}) {
    if (priority case Priority.high) {
      _highPriorityQueue.add(operation);
    } else if (priority case Priority.normal) {
      _normalPriorityQueue.add(operation);
    } else if (priority case Priority.low) {
      _lowPriorityQueue.add(operation);
    }

    pendingOperations.value = _totalPendingOperations;

    if (!_isProcessingQueue) {
      _startQueueProcessing();
    }
  }

  /// Add multiple operations to queue with priority
  void queueOperations(List<Future Function()> operations, {Priority priority = Priority.normal}) {
    if (priority case Priority.high) {
      _highPriorityQueue.addAll(operations);
    } else if (priority case Priority.normal) {
      _normalPriorityQueue.addAll(operations);
    } else if (priority case Priority.low) {
      _lowPriorityQueue.addAll(operations);
    }

    pendingOperations.value = _totalPendingOperations;

    if (!_isProcessingQueue) {
      _startQueueProcessing();
    }
  }

  /// Clear all pending operations
  void clearQueue() {
    _highPriorityQueue.clear();
    _normalPriorityQueue.clear();
    _lowPriorityQueue.clear();
    pendingOperations.value = 0;
  }

  /// Execute operation with retry logic
  Future<T?> executeWithRetry<T>(
      Future<T> Function() operation, {
        int maxRetries = 3,
        Duration retryDelay = const Duration(seconds: 1),
        bool showErrorMessage = true,
      }) async {
    int attempts = 0;
    final taskId = operation.hashCode.toString();
    final startTime = DateTime.now().millisecondsSinceEpoch;

    while (attempts < maxRetries) {
      try {
        final result = await operation();

        // Track successful task duration
        final endTime = DateTime.now().millisecondsSinceEpoch;
        final duration = endTime - startTime;
        _updateTaskDuration(taskId, duration);

        // Clear failed task record if it exists
        if (_failedTasks.containsKey(taskId)) {
          _failedTasks.remove(taskId);
          failedTaskCount.value = _failedTasks.length;
        }

        return result;
      } catch (e) {
        attempts++;
        logger.e('Operation failed (attempt $attempts/$maxRetries): $e');

        // Track failed task
        _failedTasks[taskId] = (_failedTasks[taskId] ?? 0) + 1;
        failedTaskCount.value = _failedTasks.length;

        if (attempts >= maxRetries) {
          // Show error message on final failure if requested
          if (showErrorMessage) {
            Get.showSnackbar(
              GetSnackBar(
                message: 'Operation failed after $maxRetries attempts: ${e.toString()}',
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return null;
        }

        // Wait before retrying with exponential backoff
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
        bool showErrorMessage = true,
      }) async {
    final taskId = operation.hashCode.toString();
    final startTime = DateTime.now().millisecondsSinceEpoch;

    try {
      final result = await operation().timeout(timeout);

      // Track successful task duration
      final endTime = DateTime.now().millisecondsSinceEpoch;
      final duration = endTime - startTime;
      _updateTaskDuration(taskId, duration);

      return result;
    } on TimeoutException {
      logger.w('Operation timed out after ${timeout.inSeconds} seconds');

      // Track failed task
      _failedTasks[taskId] = (_failedTasks[taskId] ?? 0) + 1;
      failedTaskCount.value = _failedTasks.length;

      if (showErrorMessage) {
        Get.showSnackbar(
          GetSnackBar(
            message: 'Operation timed out after ${timeout.inSeconds} seconds',
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      return defaultValue;
    } catch (e) {
      logger.e('Operation failed: $e');

      // Track failed task
      _failedTasks[taskId] = (_failedTasks[taskId] ?? 0) + 1;
      failedTaskCount.value = _failedTasks.length;

      if (showErrorMessage) {
        Get.showSnackbar(
          GetSnackBar(
            message: 'Operation failed: ${e.toString()}',
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      return defaultValue;
    }
  }

  /// Execute operation in an isolate for CPU-intensive tasks
  Future<T?> executeInIsolate<T>(
      Future<T> Function() operation, {
        bool showErrorMessage = true,
      }) async {
    try {
      // Use compute for true isolation
      return await compute(_isolatedOperation<T>, operation);
    } catch (e) {
      logger.e('Isolate operation failed: $e');

      if (showErrorMessage) {
        Get.showSnackbar(
          GetSnackBar(
            message: 'Background operation failed: ${e.toString()}',
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      return null;
    }
  }

  /// Static method for isolate computation
  static Future<T?> _isolatedOperation<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (e) {
      print('Error in isolate: $e');
      return null;
    }
  }

  /// Acquire a lock for a specific operation to prevent concurrent execution
  Future<void> acquireOperationLock(String operationKey) async {
    if (_operationLocks.containsKey(operationKey)) {
      // Wait for existing operation to complete
      await _operationLocks[operationKey]!.future;
    }

    // Create a new lock
    _operationLocks[operationKey] = Completer<void>();
  }

  /// Release a lock for a specific operation
  void releaseOperationLock(String operationKey) {
    if (_operationLocks.containsKey(operationKey)) {
      _operationLocks[operationKey]!.complete();
      _operationLocks.remove(operationKey);
    }
  }

  /// Get total number of pending operations
  int get _totalPendingOperations =>
      _highPriorityQueue.length +
          _normalPriorityQueue.length +
          _lowPriorityQueue.length;

  /// Update task duration tracking
  void _updateTaskDuration(String taskId, int duration) {
    if (!_taskDurations.containsKey(taskId)) {
      _taskDurations[taskId] = duration;
      averageTaskDurations[taskId] = duration;
    } else {
      // Calculate running average
      final oldAvg = _taskDurations[taskId]!;
      final newAvg = ((oldAvg * 2) + duration) ~/ 3; // Weighted average favoring recent
      _taskDurations[taskId] = newAvg;
      averageTaskDurations[taskId] = newAvg;
    }
  }

  /// Retry all failed tasks
  void retryFailedTasks() {
    final failedTaskIds = _failedTasks.keys.toList();
    for (final taskId in failedTaskIds) {
      // We can't directly retry since we don't store the operation
      // This is a placeholder for a more sophisticated retry mechanism
      logger.d('Would retry task $taskId if we had stored the operation');
    }
  }
}

/// Priority enum for queue operations
enum Priority {
  high,
  normal,
  low, medium,
}
