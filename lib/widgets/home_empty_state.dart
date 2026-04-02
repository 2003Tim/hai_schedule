import 'package:flutter/material.dart';

class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({
    super.key,
    required this.onLoginFetch,
    required this.onManualImport,
  });

  final VoidCallback onLoginFetch;
  final VoidCallback onManualImport;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final loginButtonStyle = FilledButton.styleFrom(
      elevation: 0,
      shadowColor: Colors.transparent,
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      overlayColor: colorScheme.onPrimary.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 56,
                  color: colorScheme.primary.withValues(alpha: 0.28),
                ),
                const SizedBox(height: 14),
                const Text(
                  '还没有导入课表',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '可以登录教务系统直接抓取，也可以手动粘贴导入。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.68),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  style: loginButtonStyle,
                  onPressed: onLoginFetch,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('登录并刷新课表'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onManualImport,
                  icon: const Icon(Icons.paste_rounded),
                  label: const Text('手动粘贴导入'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
