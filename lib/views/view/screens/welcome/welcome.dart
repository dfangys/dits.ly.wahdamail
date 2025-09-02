// lib/views/view/screens/welcome/welcome.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import 'package:wahda_bank/views/authantication/screens/login/login.dart';
import 'package:wahda_bank/utills/constants/sizes.dart';
import 'package:wahda_bank/utills/constants/text_strings.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  /* ───────── constants ───────── */
  static const _animDuration = Duration(milliseconds: 800);
  static const _pageDuration = Duration(milliseconds: 600);

  /* ───────── controllers ───────── */
  final PageController _pageController = PageController();
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  int _currentPage = 0;

  /* ───────── onboarding data ───────── */
  final List<Map<String, String>> _pages = [
    {
      'image': 'assets/svg/Onboarding1.svg',
      'title': 'Welcome to Wahda Bank',
      'description': WText.welcomeScreenTitle,
    },
    {
      'image': 'assets/svg/Onboarding2.svg',
      'title': 'Secure Email Access',
      'description':
          'Access your emails securely from anywhere with our advanced security features.',
    },
    {
      'image': 'assets/svg/Onboarding3.svg',
      'title': 'Stay Connected',
      'description':
          'Never miss an important message with real-time notifications and updates.',
    },
  ];

  /* ───────── life-cycle ───────── */
  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: _animDuration,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  /* ───────── helpers ───────── */
  bool get _isLastPage => _currentPage == _pages.length - 1;

  void _onSkip() => _pageController.animateToPage(
    _pages.length - 1,
    duration: _pageDuration,
    curve: Curves.easeInOut,
  );

  void _onNext() {
    if (_isLastPage) {
      Get.offAll(() => const LoginScreen()); // ← open real login & clear stack
    } else {
      _pageController.nextPage(
        duration: _pageDuration,
        curve: Curves.easeInOut,
      );
    }
  }

  /* ───────── UI ───────── */
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            margin: EdgeInsets.only(top: size.height * 0.06),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                /* PageView */
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder:
                        (_, i) => _buildPage(
                          imagePath: _pages[i]['image']!,
                          title: _pages[i]['title']!,
                          description: _pages[i]['description']!,
                          isTablet: isTablet,
                        ),
                  ),
                ),
                /* Dots */
                Padding(
                  padding: const EdgeInsets.only(bottom: 30),
                  child: SmoothPageIndicator(
                    controller: _pageController,
                    count: _pages.length,
                    effect: ExpandingDotsEffect(
                      activeDotColor: Theme.of(context).primaryColor,
                      dotColor: Colors.grey.shade300,
                      dotHeight: 8,
                      dotWidth: 8,
                      expansionFactor: 4,
                      spacing: 6,
                    ),
                  ),
                ),
                /* Buttons */
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: 40,
                    left: 20,
                    right: 20,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _isLastPage
                          ? const SizedBox(width: 80)
                          : TextButton(
                            onPressed: _onSkip,
                            child: Text(
                              'Skip',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                      ElevatedButton(
                        onPressed: _onNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          _isLastPage ? 'Get Started' : 'Next',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /* --- single onboarding page --- */
  Widget _buildPage({
    required String imagePath,
    required String title,
    required String description,
    required bool isTablet,
  }) {
    final media = MediaQuery.of(context);
    final imgHeight = media.size.height / (isTablet ? 2.8 : 2.5);

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.only(
              top: isTablet ? 70 : 50,
              bottom: isTablet ? 40 : 30,
              left: 20,
              right: 20,
            ),
            child:
                imagePath.toLowerCase().endsWith('.svg')
                    ? SvgPicture.asset(imagePath, height: imgHeight)
                    : Image.asset(
                      imagePath,
                      height: imgHeight,
                      fit: BoxFit.contain,
                    ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: isTablet ? 28 : 22,
            ),
          ),
          SizedBox(
            width: 80,
            child: Divider(
              height: 10,
              thickness: 3,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: WSizes.defaultSpace),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 40 : 20),
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
