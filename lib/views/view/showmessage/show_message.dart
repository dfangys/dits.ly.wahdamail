import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:wahda_bank/views/view/showmessage/widgets/inbox_app_bar.dart';
import 'package:wahda_bank/views/view/showmessage/widgets/inbox_bottom_navbar.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:wahda_bank/utills/constants/sizes.dart';
import 'package:wahda_bank/views/view/showmessage/widgets/mail_attachments.dart';
import 'package:wahda_bank/views/view/showmessage/widgets/mail_meta_tile.dart';
import 'package:get/get.dart';

class ShowMessage extends StatefulWidget {
  const ShowMessage({super.key, required this.message, required this.mailbox});
  final MimeMessage message;
  final Mailbox mailbox;

  @override
  State<ShowMessage> createState() => _ShowMessageState();
}

class _ShowMessageState extends State<ShowMessage> with SingleTickerProviderStateMixin {
  final ValueNotifier<bool> showMeta = ValueNotifier<bool>(false);
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();

    // Fix iOS status bar visibility
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get name {
    if (widget.message.from != null && widget.message.from!.isNotEmpty) {
      return widget.message.from!.first.personalName ?? widget.message.from!.first.email;
    } else if (widget.message.fromEmail == null) {
      return "Unknown";
    }
    return widget.message.fromEmail ?? "Unknown";
  }

  String get email {
    if (widget.message.from != null && widget.message.from!.isNotEmpty) {
      return widget.message.from!.first.email;
    } else if (widget.message.fromEmail == null) {
      return "Unknown";
    }
    return widget.message.fromEmail ?? "Unknown";
  }

  String get formattedDate {
    final date = widget.message.decodeDate() ?? DateTime.now();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return "Today, ${DateFormat("h:mm a").format(date)}";
    } else if (difference.inDays == 1) {
      return "Yesterday, ${DateFormat("h:mm a").format(date)}";
    } else if (difference.inDays < 7) {
      return DateFormat("EEEE, h:mm a").format(date);
    } else {
      return DateFormat("MMM d, yyyy, h:mm a").format(date);
    }
  }

  Color get senderColor {
    // Generate a consistent color based on the sender's name
    final colorIndex = name.hashCode % AppTheme.colorPalette.length;
    return AppTheme.colorPalette[colorIndex];
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isTablet ? 70 : 60),
        child: InbocAppBar(
          message: widget.message,
          mailbox: widget.mailbox,
        ),
      ),
      bottomNavigationBar: ViewMessageBottomNav(
        mailbox: widget.mailbox,
        message: widget.message,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Email header card
              SliverToBoxAdapter(
                child: Container(
                  margin: EdgeInsets.all(isTablet ? 20 : 16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sender info with staggered animation
                      _buildSenderInfo(isTablet),

                      // Email metadata (expandable)
                      MailMetaTile(message: widget.message, isShow: showMeta),

                      // Subject with animation
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, (1 - value) * 20),
                              child: child,
                            ),
                          );
                        },
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            isTablet ? 20 : 16,
                            8,
                            isTablet ? 20 : 16,
                            isTablet ? 20 : 16,
                          ),
                          child: Text(
                            widget.message.decodeSubject() ?? 'No Subject',
                            style: TextStyle(
                              fontSize: isTablet ? 22 : 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Attachments and content
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: isTablet ? 20 : 16),
                sliver: SliverToBoxAdapter(
                  child: MailAttachments(message: widget.message),
                ),
              ),

              // Bottom padding
              SliverToBoxAdapter(
                child: SizedBox(height: isTablet ? 32 : 24),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildScrollToTopFAB(),
    );
  }

  Widget _buildSenderInfo(bool isTablet) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 20),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar with hero animation
            Hero(
              tag: 'avatar_${widget.message.sequenceId}',
              child: Container(
                width: isTablet ? 56 : 48,
                height: isTablet ? 56 : 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: senderColor,
                  boxShadow: [
                    BoxShadow(
                      color: senderColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isTablet ? 22 : 18,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: isTablet ? 20 : 16),

            // Sender details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: isTablet ? 15 : 14,
                      color: AppTheme.textSecondaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Date and metadata toggle
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<bool>(
                  valueListenable: showMeta,
                  builder: (context, value, child) {
                    return InkWell(
                      onTap: () {
                        showMeta.value = !showMeta.value;
                      },
                      borderRadius: BorderRadius.circular(50),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: value
                              ? AppTheme.primaryColor.withOpacity(0.1)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          value
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: value
                              ? AppTheme.primaryColor
                              : AppTheme.textSecondaryColor,
                          size: 20,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollToTopFAB() {
    return AnimatedBuilder(
      animation: _scrollController,
      builder: (context, child) {
        // Only show FAB when scrolled down
        if (_scrollController.hasClients && _scrollController.offset > 300) {
          return FloatingActionButton.small(
            onPressed: () {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
              );
            },
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            elevation: 2,
            child: const Icon(Icons.arrow_upward_rounded),
          );
        }
        // Return an empty widget instead of null
        return const SizedBox.shrink();
      },
    );
  }
}
