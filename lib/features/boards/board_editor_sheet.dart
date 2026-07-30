import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/board.dart';
import '../../core/models/enums.dart';
import '../../core/theme/app_geometry.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/context_x.dart';
import '../../state/boards_controller.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/pressable.dart';

/// Create or edit a board. Returns the saved board, or null if cancelled.
Future<Board?> showBoardEditorSheet(
  BuildContext context, {
  Board? existing,
}) {
  return showAppSheet<Board>(
    context: context,
    semanticLabel: existing == null ? 'New board' : 'Edit board',
    builder: (_) => _BoardEditorSheet(existing: existing),
  );
}

class _BoardEditorSheet extends ConsumerStatefulWidget {
  const _BoardEditorSheet({this.existing});

  final Board? existing;

  @override
  ConsumerState<_BoardEditorSheet> createState() => _BoardEditorSheetState();
}

class _BoardEditorSheetState extends ConsumerState<_BoardEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  final _titleFocus = FocusNode();

  late int _color;
  late String _iconKey;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final suggestion = suggestBoardStyle(ref.read(boardsProvider).length);

    _title = TextEditingController(text: existing?.title ?? '');
    _description = TextEditingController(text: existing?.description ?? '');
    _color = existing?.colorValue ?? suggestion.color;
    _iconKey = existing?.iconKey ?? suggestion.iconKey;

    if (!_isEditing) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _titleFocus.requestFocus());
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Boards need a name');
      _titleFocus.requestFocus();
      return;
    }

    final controller = ref.read(boardsProvider.notifier);
    final Board saved;

    if (_isEditing) {
      saved = widget.existing!.copyWith(
        title: title,
        description: _description.text.trim(),
        colorValue: _color,
        iconKey: _iconKey,
      );
      await controller.update(saved);
    } else {
      saved = await controller.create(
        title: title,
        description: _description.text.trim(),
        colorValue: _color,
        iconKey: _iconKey,
      );
    }

    if (mounted) Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = Color(_color);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SheetHeader(
            title: _isEditing ? 'Edit board' : 'New board',
            subtitle: 'Give it a name, a colour and a glyph.',
          ),

          // Live preview so the colour/icon choices are legible before saving.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppGeometry.xl),
            child: Container(
              padding: const EdgeInsets.all(AppGeometry.lg),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: colors.isDark ? 0.16 : 0.1),
                borderRadius: AppGeometry.brLg,
                border: Border.all(color: accent.withValues(alpha: 0.34)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: AppGeometry.brMd,
                    ),
                    child: Icon(
                      BoardIcons.resolve(_iconKey),
                      color: AppColors.onAccent(accent),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppGeometry.md),
                  Expanded(
                    child: Text(
                      _title.text.trim().isEmpty
                          ? 'Board name'
                          : _title.text.trim(),
                      style: context.text.titleLarge?.copyWith(
                        color: _title.text.trim().isEmpty
                            ? colors.textTertiary
                            : colors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppGeometry.xl),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppGeometry.xl),
            child: Column(
              children: [
                TextField(
                  controller: _title,
                  focusNode: _titleFocus,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() => _error = null),
                  decoration: InputDecoration(
                    labelText: 'Name',
                    hintText: 'Work, Personal, Study…',
                    errorText: _error,
                  ),
                ),
                const SizedBox(height: AppGeometry.md),
                TextField(
                  controller: _description,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  minLines: 1,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Optional — what belongs here?',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppGeometry.xl),

          _Label('Colour'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppGeometry.xl),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final value in Brand.boardAccentValues)
                  _ColorSwatch(
                    value: value,
                    selected: _color == value,
                    onTap: () => setState(() => _color = value),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppGeometry.xl),

          _Label('Icon'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppGeometry.xl),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in BoardIcons.options.entries)
                  _IconSwatch(
                    iconKey: entry.key,
                    icon: entry.value,
                    accent: accent,
                    selected: _iconKey == entry.key,
                    onTap: () => setState(() => _iconKey = entry.key),
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppGeometry.xxl),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppGeometry.xl,
              0,
              AppGeometry.xl,
              AppGeometry.xl,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: AppColors.onAccent(accent),
                ),
                child: Text(_isEditing ? 'Save changes' : 'Create board'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppGeometry.xl,
        0,
        AppGeometry.xl,
        AppGeometry.md,
      ),
      child: Text(
        text.toUpperCase(),
        style: context.text.labelSmall?.copyWith(
          color: context.colors.textTertiary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(value);
    return Pressable(
      onTap: onTap,
      haptic: null,
      borderRadius: BorderRadius.circular(999),
      minSize: 48,
      semanticLabel: 'Board colour',
      child: AnimatedContainer(
        duration: context.motion.fast,
        curve: context.motion.overshoot,
        width: selected ? 40 : 34,
        height: selected ? 40 : 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? context.colors.textPrimary : Colors.transparent,
            width: 2,
          ),
        ),
        child: selected
            ? Icon(Icons.check_rounded, size: 18, color: AppColors.onAccent(color))
            : null,
      ),
    );
  }
}

class _IconSwatch extends StatelessWidget {
  const _IconSwatch({
    required this.iconKey,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final String iconKey;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Pressable(
      onTap: onTap,
      haptic: null,
      borderRadius: AppGeometry.brMd,
      minSize: 48,
      semanticLabel: 'Icon $iconKey',
      child: AnimatedContainer(
        duration: context.motion.fast,
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: colors.isDark ? 0.24 : 0.14)
              : colors.surfaceSunken,
          borderRadius: AppGeometry.brMd,
          border: Border.all(
            color: selected ? accent : colors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: selected ? accent : colors.textSecondary,
        ),
      ),
    );
  }
}
