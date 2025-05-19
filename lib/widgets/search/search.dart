import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:wahda_bank/app/controllers/mailbox_list_controller.dart';
import 'package:wahda_bank/utills/constants/colors.dart';
import 'package:wahda_bank/views/view/showmessage/show_message.dart';
import 'package:wahda_bank/widgets/mail_tile.dart';
import '../empty_box.dart';
import 'controllers/mail_search_controller.dart';

class SearchView extends StatelessWidget {
  SearchView({super.key});
  final controller = Get.put(MailSearchController());
  final mailboxController = Get.find<MailboxListController>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: _buildSearchBar(context),
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: theme.colorScheme.primary,
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
          child: controller.obx(
                (state) => _buildSearchResults(context),
            onEmpty: _buildEmptyState(context, 'Whoops! Box is empty', 'try_again'.tr),
            onLoading: _buildLoadingState(context),
            onError: (error) => _buildErrorState(context, error),
          ),
        ),
      ),
    );
  }

  // Modern search bar with animation and visual feedback
  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);

    return Hero(
      tag: 'searchBar',
      child: Material(
        color: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: 56,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextFormField(
            controller: controller.searchController,
            onChanged: (String txt) {},
            style: theme.textTheme.bodyLarge,
            cursorColor: theme.colorScheme.primary,
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              fillColor: Colors.transparent,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 20,
              ),
              hintText: "search".tr,
              hintStyle: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              prefixIcon: Icon(
                Icons.search_rounded,
                color: theme.colorScheme.primary,
                size: 22,
              ),
              suffixIcon: Container(
                margin: const EdgeInsets.only(right: 8),
                child: Material(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: () {
                      controller.onSearch();
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: theme.colorScheme.onPrimary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Modern search results with animations and visual hierarchy
  Widget _buildSearchResults(BuildContext context) {
    final theme = Theme.of(context);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      controller: controller.scrollController,
      itemBuilder: (context, index) {
        // Add staggered animation for list items
        return AnimatedContainer(
          duration: Duration(milliseconds: 300 + (index * 50)),
          curve: Curves.easeOutQuint,
          transform: Matrix4.translationValues(0, 0, 0),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Get.to(
                        () => ShowMessage(
                      message: controller.searchMessages[index],
                      mailbox: mailboxController.mailBoxInbox,
                    ),
                    transition: Transition.rightToLeft,
                    duration: const Duration(milliseconds: 250),
                  );
                },
                splashColor: theme.colorScheme.primary.withOpacity(0.1),
                highlightColor: theme.colorScheme.primary.withOpacity(0.05),
                child: MailTile(
                  message: controller.searchMessages[index],
                  mailBox: mailboxController.mailBoxInbox,
                  onTap: () {
                    Get.to(
                          () => ShowMessage(
                        message: controller.searchMessages[index],
                        mailbox: mailboxController.mailBoxInbox,
                      ),
                      transition: Transition.rightToLeft,
                      duration: const Duration(milliseconds: 250),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
      itemCount: controller.searchMessages.length,
    );
  }

  // Modern loading state with animation
  Widget _buildLoadingState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Searching...',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Finding the best results for you',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // Modern empty state with improved visuals
  Widget _buildEmptyState(BuildContext context, String message, String actionText) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: ModernAnimationLoaderWidget(
        text: message,
        animation: 'assets/lottie/empty.json',
        showAction: true,
        actionText: actionText,
        onActionPressed: () {
          controller.onSearch();
        },
      ),
    );
  }

  // Modern error state with improved visuals
  Widget _buildErrorState(BuildContext context, String? error) {
    if (error == null) return const SizedBox();

    if (error.toString().startsWith('serach:')) {
      return Container(
        margin: const EdgeInsets.all(16),
        child: ModernAnimationLoaderWidget(
          text: error.toString().split('serach:')[1],
          animation: 'assets/lottie/search.json',
          showAction: true,
          actionText: 'search'.tr,
          onActionPressed: () {
            controller.onSearch();
          },
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      child: ModernAnimationLoaderWidget(
        text: error.toString(),
        animation: 'assets/lottie/error.json',
        showAction: false,
        actionText: 'try_again'.tr,
        onActionPressed: () {},
      ),
    );
  }
}

// This is a renamed version of TAnimationLoaderWidget to maintain compatibility
// while applying modern design principles
class ModernAnimationLoaderWidget extends StatelessWidget {
  const ModernAnimationLoaderWidget({
    super.key,
    required this.text,
    required this.animation,
    this.showAction = false,
    this.actionText,
    this.onActionPressed,
  });

  final String text;
  final String animation;
  final bool showAction;
  final String? actionText;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Lottie animation with improved sizing
            Container(
              width: MediaQuery.of(context).size.width * 0.7,
              height: MediaQuery.of(context).size.width * 0.7,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.all(24),
              child: Lottie.asset(
                animation,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 32),

            // Message text with improved typography
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8,
              ),
              child: Text(
                text,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onBackground,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Action button with modern styling
            if (showAction) ...[
              const SizedBox(height: 32),
              SizedBox(
                width: 200,
                height: 56,
                child: ElevatedButton(
                  onPressed: onActionPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        actionText!,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
