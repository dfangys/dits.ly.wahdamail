import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'dart:io';
import 'package:get_storage/get_storage.dart';
import 'package:wahda_bank/views/view/models/box_model.dart';
import 'package:wahda_bank/services/background_service.dart';
import '../../../services/mail_service.dart';
import '../../../utills/constants/image_strings.dart';

class LoadingFirstView extends StatefulWidget {
  const LoadingFirstView({super.key});

  @override
  State<LoadingFirstView> createState() => _LoadingFirstViewState();
}

class _LoadingFirstViewState extends State<LoadingFirstView>
    with SingleTickerProviderStateMixin {
  final GetStorage storage = GetStorage();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;

  String error = '';
  bool _isLoading = true;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _rotateAnimation = Tween<double>(begin: 0.0, end: 0.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Start animation
    _animationController.forward();

    // Simulate progress
    _startProgressSimulation();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      init();
    });
  }

  void _startProgressSimulation() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;

      setState(() {
        _progress = 0.2;
      });

      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;

        setState(() {
          _progress = 0.5;
        });

        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return;

          setState(() {
            _progress = 0.8;
          });
        });
      });
    });
  }

  Future init() async {
    bool isReadyToRun = true;
    try {
      if (!storage.hasData('first_run')) {
        await MailService.instance.init();
        await MailService.instance.connect();
        List<Mailbox> boxes = await MailService.instance.client.listMailboxes();
        List<Map<String, dynamic>> v = [];
        for (var box in boxes) {
          v.add(BoxModel.toJson(box));
        }
        await storage.write('boxes', v);
        await storage.write('first_run', true);
      }

      setState(() {
        _progress = 1.0;
      });

      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      isReadyToRun = false;
      printError(info: e.toString());
      error = e.toString();

      setState(() {
        _isLoading = false;
      });
    } finally {
      if (isReadyToRun) {
        try {
          if (Platform.isAndroid) {
            await BackgroundService.startService();
          } else {
            debugPrint('Background scheduling skipped on non-Android platform');
          }
        } catch (e) {
          debugPrint('Background service start error: $e');
        }
        Get.offAllNamed('/home');
      } else {
        AwesomeDialog(
          context: Get.context!,
          dialogType: DialogType.error,
          title: 'Error',
          desc:
              'An error occurred while trying to connect to the server. $error',
          btnOkOnPress: () {
            Get.back();
          },
        ).show();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      body: Container(
        constraints: const BoxConstraints.expand(),
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(WImages.background),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated logo
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Transform.rotate(
                        angle:
                            _animationController.value % 1 == 0.5
                                ? _rotateAnimation.value
                                : -_rotateAnimation.value,
                        child: SizedBox(
                          height: isTablet ? 140.0 : 105.0,
                          width: isTablet ? 360.0 : 273.0,
                          child: SvgPicture.asset(
                            WImages.logoWhite,
                            colorFilter: const ColorFilter.mode(
                              Colors.white,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              // Progress indicator
              if (_isLoading)
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      // Custom progress bar
                      Container(
                        width: isTablet ? 280 : 220,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Stack(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeInOut,
                              width: (isTablet ? 280 : 220) * _progress,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Loading text
                      Text(
                        'Loading your mailbox...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
