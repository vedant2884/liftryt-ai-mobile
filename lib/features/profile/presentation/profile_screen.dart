import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_prefs.dart';
import '../../../shared/widgets/app_card.dart';
import '../../auth/data/models.dart';
import '../../auth/state/auth_controller.dart';
import '../../library/presentation/library_screen.dart';
import '../../macros/presentation/macros_screen.dart';
import '../../splits/presentation/splits_screen.dart';
import '../../weight/presentation/weight_screen.dart';

/// Profile / Settings hub — mirrors what `frontend/src/pages/ProfilePage.tsx`
/// exposes (default progression increment, preferred split, logout) plus
/// serves as the mobile "more" entry point for Weight/Macros/Library, which
/// don't have their own bottom-nav tab.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _incrementController = TextEditingController();
  bool _savingIncrement = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = ref.read(authControllerProvider).user;
    if (user != null && _incrementController.text.isEmpty) {
      _incrementController.text = user.defaultProgressionIncrementKg.toString();
    }
  }

  @override
  void dispose() {
    _incrementController.dispose();
    super.dispose();
  }

  Future<void> _setThemeMode(AppThemeMode mode) async {
    ref.read(authControllerProvider.notifier).applyThemePreview(theme: mode);
    unawaited(ref.read(themePrefsProvider).save(themeMode: mode));
    await ref.read(authControllerProvider.notifier).updateProfile(theme: mode);
  }

  Future<void> _setAccentColor(AccentColor accent) async {
    ref.read(authControllerProvider.notifier).applyThemePreview(accentColor: accent);
    unawaited(ref.read(themePrefsProvider).save(accentColor: accent));
    await ref.read(authControllerProvider.notifier).updateProfile(accentColor: accent);
  }

  Future<void> _setWorkoutRemindersEnabled(bool enabled) async {
    await ref.read(authControllerProvider.notifier).updateProfile(workoutRemindersEnabled: enabled);
  }

  Future<void> _saveIncrement() async {
    final value = double.tryParse(_incrementController.text);
    if (value == null || value <= 0) return;
    setState(() => _savingIncrement = true);
    try {
      await ref.read(authControllerProvider.notifier).updateProfile(defaultProgressionIncrementKg: value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Default increment updated')));
      }
    } finally {
      if (mounted) setState(() => _savingIncrement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            Text('Profile', style: TextStyle(color: context.colors.ink, fontSize: 24, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            AppCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: context.colors.accent.withValues(alpha: 0.15),
                    child: Text(
                      (user?.fullName.isNotEmpty ?? false) ? user!.fullName[0].toUpperCase() : '?',
                      style: TextStyle(color: context.colors.accent, fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.fullName ?? '',
                            style: TextStyle(color: context.colors.ink, fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(user?.email ?? '', style: TextStyle(color: context.colors.inkMuted, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Appearance', style: TextStyle(color: context.colors.inkMuted, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _appearanceCard(user),
            const SizedBox(height: 20),
            Text('Notifications', style: TextStyle(color: context.colors.inkMuted, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Workout reminders', style: TextStyle(color: context.colors.ink, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          'Occasional, behavior-based nudges — never more than one at a time.',
                          style: TextStyle(color: context.colors.inkMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: user?.workoutRemindersEnabled ?? true,
                    activeThumbColor: context.colors.accent,
                    onChanged: _setWorkoutRemindersEnabled,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('More', style: TextStyle(color: context.colors.inkMuted, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _navRow(Icons.monitor_weight_outlined, 'Weight', () => _push(const WeightScreen())),
                  Divider(color: context.colors.line, height: 1),
                  _navRow(Icons.pie_chart_outline_rounded, 'Macros', () => _push(const MacrosScreen())),
                  Divider(color: context.colors.line, height: 1),
                  _navRow(Icons.menu_book_outlined, 'Exercise Library', () => _push(const LibraryScreen())),
                  Divider(color: context.colors.line, height: 1),
                  _navRow(Icons.calendar_month_outlined, 'Workout Splits', () => _push(const SplitsScreen())),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Progression', style: TextStyle(color: context.colors.inkMuted, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Default weight increment', style: TextStyle(color: context.colors.ink, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Used for every exercise unless it has its own override (set from Progress).',
                      style: TextStyle(color: context.colors.inkMuted, fontSize: 11)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _incrementController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(isDense: true, suffixText: 'kg'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _savingIncrement ? null : _saveIncrement,
                        child: Text(_savingIncrement ? 'Saving...' : 'Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => ref.read(authControllerProvider.notifier).logout(),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Log out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF87171),
                  side: const BorderSide(color: Color(0xFFF87171)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Widget _appearanceCard(UserProfile? user) {
    final prefs = ref.watch(themePrefsProvider);
    final mode = user?.theme ?? prefs.themeMode;
    final accent = user?.accentColor ?? prefs.accentColor;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mode', style: TextStyle(color: context.colors.inkSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: context.colors.bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.colors.line),
            ),
            child: Row(
              children: [
                for (final entry in const [
                  (AppThemeMode.dark, Icons.dark_mode_outlined, 'Dark'),
                  (AppThemeMode.light, Icons.light_mode_outlined, 'Light'),
                  (AppThemeMode.system, Icons.brightness_auto_outlined, 'System'),
                ])
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _setThemeMode(entry.$1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: mode == entry.$1 ? context.colors.accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Icon(entry.$2, size: 16, color: mode == entry.$1 ? Colors.white : context.colors.inkSecondary),
                            const SizedBox(height: 2),
                            Text(entry.$3,
                                style: TextStyle(
                                    fontSize: 11, color: mode == entry.$1 ? Colors.white : context.colors.inkSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Accent', style: TextStyle(color: context.colors.inkSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final entry in const [
                (AccentColor.violet, Color(0xFF8B5CF6), 'Violet'),
                (AccentColor.emerald, Color(0xFF10B981), 'Emerald'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => _setAccentColor(entry.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: accent == entry.$1 ? entry.$2 : context.colors.line,
                          width: accent == entry.$1 ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(color: entry.$2, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(entry.$3, style: TextStyle(color: context.colors.ink, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navRow(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: context.colors.inkSecondary, size: 20),
      title: Text(label, style: TextStyle(color: context.colors.ink, fontSize: 14)),
      trailing: Icon(Icons.chevron_right_rounded, color: context.colors.inkMuted, size: 20),
      onTap: onTap,
    );
  }
}
