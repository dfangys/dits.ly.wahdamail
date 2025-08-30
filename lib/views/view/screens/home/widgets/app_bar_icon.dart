import 'package:flutter/material.dart';
import 'package:wahda_bank/views/compose/widgets/compose_modal.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';

class HomeAppBarIcon extends StatelessWidget {
  const HomeAppBarIcon({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        ComposeModal.show(context);
      },
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 10, right: 16, left: 10),
        height: 36,
        width: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: AppTheme.primaryColor,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha : 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.add,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}
