import 'package:flutter/material.dart';
import 'package:get/get.dart';

class EmailDownloadProgressWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final double? progress;
  final int? currentCount;
  final int? totalCount;
  final bool isIndeterminate;

  const EmailDownloadProgressWidget({
    super.key,
    required this.title,
    required this.subtitle,
    this.progress,
    this.currentCount,
    this.totalCount,
    this.isIndeterminate = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.email,
              size: 32,
              color: theme.primaryColor,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Title
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // Subtitle
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 20),
          
          // Progress indicator
          if (isIndeterminate)
            LinearProgressIndicator(
              backgroundColor: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
            )
          else if (progress != null)
            Column(
              children: [
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                ),
                const SizedBox(height: 8),
                if (currentCount != null && totalCount != null)
                  Text(
                    '$currentCount / $totalCount emails',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
              ],
            )
          else
            const CircularProgressIndicator(),
          
          const SizedBox(height: 16),
          
          // Animated dots
          const _AnimatedDots(),
        ],
      ),
    );
  }
}

class _AnimatedDots extends StatefulWidget {
  const _AnimatedDots();

  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = IntTween(begin: 0, end: 3).animate(_controller);
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        String dots = '';
        for (int i = 0; i < _animation.value; i++) {
          dots += '•';
        }
        return Text(
          'Loading$dots',
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
            letterSpacing: 1.2,
          ),
        );
      },
    );
  }
}

class EmailDownloadProgressController extends GetxController {
  final RxString _title = 'Loading Emails'.obs;
  final RxString _subtitle = 'Please wait while we fetch your emails...'.obs;
  final RxDouble _progress = 0.0.obs;
  final RxInt _currentCount = 0.obs;
  final RxInt _totalCount = 0.obs;
  final RxBool _isVisible = false.obs;
  final RxBool _isIndeterminate = true.obs;

  String get title => _title.value;
  String get subtitle => _subtitle.value;
  double get progress => _progress.value;
  int get currentCount => _currentCount.value;
  int get totalCount => _totalCount.value;
  bool get isVisible => _isVisible.value;
  bool get isIndeterminate => _isIndeterminate.value;

  void show({
    String? title,
    String? subtitle,
    bool indeterminate = true,
  }) {
    if (title != null) _title.value = title;
    if (subtitle != null) _subtitle.value = subtitle;
    _isIndeterminate.value = indeterminate;
    _isVisible.value = true;
  }

  void updateProgress({
    double? progress,
    int? current,
    int? total,
    String? subtitle,
  }) {
    if (progress != null) {
      _progress.value = progress;
      _isIndeterminate.value = false;
    }
    if (current != null) _currentCount.value = current;
    if (total != null) _totalCount.value = total;
    if (subtitle != null) _subtitle.value = subtitle;
  }

  void updateStatus(String status) {
    _subtitle.value = status;
  }

  void hide() {
    _isVisible.value = false;
    _progress.value = 0.0;
    _currentCount.value = 0;
    _totalCount.value = 0;
    _isIndeterminate.value = true;
  }
}

