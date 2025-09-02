import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/views/compose/controller/compose_controller.dart';

class PendingDraftAttachmentTile extends StatelessWidget {
  final DraftAttachmentMeta meta;
  final VoidCallback onReattach;
  final VoidCallback onView;

  const PendingDraftAttachmentTile({
    super.key,
    required this.meta,
    required this.onReattach,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extension = _extension(meta.fileName).toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.insert_drive_file_outlined,
              color: theme.colorScheme.tertiary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  meta.fileName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      extension,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.tertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '•',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _formatSize(meta.size),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: onView,
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: Text('view'.tr),
                  ),
                  FilledButton.icon(
                    onPressed: onReattach,
                    icon: const Icon(Icons.attach_file_rounded, size: 16),
                    label: Text('reattach'.tr),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _extension(String name) {
    final i = name.lastIndexOf('.');
    if (i <= 0 || i == name.length - 1) return '';
    return name.substring(i + 1);
  }

  String _formatSize(int? size) {
    if (size == null || size <= 0) return 'Unknown size';
    const units = ['B', 'KB', 'MB', 'GB'];
    double s = size.toDouble();
    int idx = 0;
    while (s >= 1024 && idx < units.length - 1) {
      s /= 1024;
      idx++;
    }
    return '${s.toStringAsFixed(s < 10 ? 1 : 0)} ${units[idx]}';
  }
}
