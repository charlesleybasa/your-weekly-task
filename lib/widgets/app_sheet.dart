import 'package:flutter/material.dart';

import '../core/theme/app_geometry.dart';
import '../core/utils/context_x.dart';

/// Modal bottom sheet with the app's motion and safe-area handling.
///
/// Always scroll-controlled and keyboard-aware: a sheet with a text field must
/// ride above the keyboard rather than hiding behind it.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  String? semanticLabel,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    backgroundColor: Colors.transparent,
    barrierColor: context.colors.scrim,
    barrierLabel: semanticLabel ?? MaterialLocalizations.of(context).modalBarrierDismissLabel,
    builder: (sheetContext) => Padding(
      // Lift the sheet above the keyboard.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _SheetShell(child: builder(sheetContext)),
    ),
  );
}

class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        maxWidth: AppGeometry.contentMaxWidth,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppGeometry.brSheet,
        border: Border(
          top: BorderSide(color: colors.border),
          left: BorderSide(color: colors.border),
          right: BorderSide(color: colors.border),
        ),
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}

/// Standard sheet header: grab handle, title, optional trailing action.
class SheetHeader extends StatelessWidget {
  const SheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onClose,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppGeometry.xl,
        AppGeometry.lg,
        AppGeometry.md,
        AppGeometry.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: context.text.headlineSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: context.text.bodySmall),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
          if (onClose != null)
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Close',
              iconSize: 22,
            ),
        ],
      ),
    );
  }
}

/// Confirmation dialog. Destructive actions get the danger colour and are
/// never the default-focused button.
Future<bool> confirmAction({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final colors = context.colors;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppGeometry.md,
        0,
        AppGeometry.md,
        AppGeometry.md,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: colors.danger,
                  foregroundColor: Colors.white,
                )
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
