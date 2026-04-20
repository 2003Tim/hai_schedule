import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hai_schedule/services/auth_credentials_service.dart';

typedef AsyncBoolCallback = Future<void> Function(bool value);
typedef AsyncVoidCallback = Future<void> Function();

class LoginCredentialDialogResult {
  const LoginCredentialDialogResult({
    required this.rememberPassword,
    required this.username,
    required this.password,
  });

  final bool rememberPassword;
  final String username;
  final String password;
}

class LoginSemesterSelection {
  const LoginSemesterSelection(this.semesterCode);

  final String? semesterCode;
}

class LoginRememberPasswordTile extends StatelessWidget {
  const LoginRememberPasswordTile({
    super.key,
    required this.isFetching,
    required this.rememberPassword,
    required this.activeCredential,
    required this.hasSavedCredential,
    required this.onRememberPasswordChanged,
    required this.onManageCredential,
  });

  final bool isFetching;
  final bool rememberPassword;
  final SavedPortalCredential? activeCredential;
  final bool hasSavedCredential;
  final AsyncBoolCallback onRememberPasswordChanged;
  final AsyncVoidCallback onManageCredential;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: ListTile(
        dense: true,
        leading: Checkbox(
          value: rememberPassword,
          onChanged:
              isFetching
                  ? null
                  : (value) {
                    if (value == null) return;
                    unawaited(onRememberPasswordChanged(value));
                  },
        ),
        title: const Text('记住密码'),
        subtitle: Text(
          activeCredential == null
              ? '输入账号后可直接登录并同步；勾选后会安全保存到本机'
              : hasSavedCredential
              ? '当前已保存账号：${activeCredential!.maskedUsername}'
              : '当前临时账号：${activeCredential!.maskedUsername}（仅本次会话有效）',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.66),
          ),
        ),
        trailing: TextButton(
          onPressed: isFetching ? null : () => unawaited(onManageCredential()),
          child: Text(activeCredential == null ? '输入账号' : '更换账号'),
        ),
      ),
    );
  }
}

class LoginStatusBanner extends StatelessWidget {
  const LoginStatusBanner({
    super.key,
    required this.isFetching,
    required this.statusText,
    required this.selectedSemesterCode,
    required this.selectedSemesterLabel,
    this.activeBackgroundColor,
    this.idleBackgroundColor,
    this.textStyle,
  });

  final bool isFetching;
  final String statusText;
  final String? selectedSemesterCode;
  final String? selectedSemesterLabel;
  final Color? activeBackgroundColor;
  final Color? idleBackgroundColor;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color:
          isFetching
              ? (activeBackgroundColor ??
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.08))
              : (idleBackgroundColor ?? Colors.transparent),
      child: Row(
        children: [
          if (isFetching)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Expanded(
            child: Text(
              selectedSemesterCode == null
                  ? statusText
                  : '目标学期 ${selectedSemesterLabel ?? selectedSemesterCode} · $statusText',
              style:
                  textStyle ??
                  TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.60),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoginFlowScaffold extends StatelessWidget {
  const LoginFlowScaffold({
    super.key,
    required this.isFetching,
    required this.canManualFetch,
    required this.rememberPassword,
    required this.activeCredential,
    required this.hasSavedCredential,
    required this.selectedSemesterCode,
    required this.selectedSemesterLabel,
    required this.statusText,
    required this.onOpenCredentialEditor,
    required this.onClearSavedCredential,
    required this.onPickTargetSemester,
    required this.onAutoFetch,
    required this.onRememberPasswordChanged,
    required this.content,
    this.activeBackgroundColor,
    this.idleBackgroundColor,
    this.statusTextStyle,
  });

  final bool isFetching;
  final bool canManualFetch;
  final bool rememberPassword;
  final SavedPortalCredential? activeCredential;
  final bool hasSavedCredential;
  final String? selectedSemesterCode;
  final String? selectedSemesterLabel;
  final String statusText;
  final AsyncVoidCallback onOpenCredentialEditor;
  final AsyncVoidCallback onClearSavedCredential;
  final AsyncVoidCallback onPickTargetSemester;
  final AsyncVoidCallback onAutoFetch;
  final AsyncBoolCallback onRememberPasswordChanged;
  final Widget content;
  final Color? activeBackgroundColor;
  final Color? idleBackgroundColor;
  final TextStyle? statusTextStyle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录教务系统'),
        actions: [
          if (!isFetching)
            IconButton(
              tooltip: '输入账号',
              onPressed: () => unawaited(onOpenCredentialEditor()),
              icon: const Icon(Icons.manage_accounts_outlined),
            ),
          if (!isFetching && activeCredential != null)
            IconButton(
              tooltip: '清除凭据',
              onPressed: () => unawaited(onClearSavedCredential()),
              icon: const Icon(Icons.logout_rounded),
            ),
          if (!isFetching)
            TextButton.icon(
              onPressed: () => unawaited(onPickTargetSemester()),
              icon: const Icon(Icons.school_outlined, size: 18),
              label: Text(
                selectedSemesterCode == null
                    ? '自动学期'
                    : (selectedSemesterLabel ?? selectedSemesterCode!),
              ),
            ),
          if (canManualFetch && !isFetching)
            TextButton.icon(
              onPressed: () => unawaited(onAutoFetch()),
              icon: const Icon(Icons.download, size: 18),
              label: const Text('手动抓取'),
            ),
        ],
      ),
      body: Column(
        children: [
          LoginRememberPasswordTile(
            isFetching: isFetching,
            rememberPassword: rememberPassword,
            activeCredential: activeCredential,
            hasSavedCredential: hasSavedCredential,
            onRememberPasswordChanged: onRememberPasswordChanged,
            onManageCredential: onOpenCredentialEditor,
          ),
          LoginStatusBanner(
            isFetching: isFetching,
            statusText: statusText,
            selectedSemesterCode: selectedSemesterCode,
            selectedSemesterLabel: selectedSemesterLabel,
            activeBackgroundColor: activeBackgroundColor,
            idleBackgroundColor: idleBackgroundColor,
            textStyle: statusTextStyle,
          ),
          Expanded(child: content),
        ],
      ),
    );
  }
}

Future<LoginCredentialDialogResult?> showLoginCredentialEditorDialog({
  required BuildContext context,
  required SavedPortalCredential? currentCredential,
  required bool rememberPassword,
  bool force = false,
}) async {
  final usernameController = TextEditingController(
    text: currentCredential?.username ?? '',
  );
  final passwordController = TextEditingController(
    text: currentCredential?.password ?? '',
  );
  bool remember = rememberPassword || force;
  bool obscure = true;

  return showDialog<LoginCredentialDialogResult>(
    context: context,
    barrierDismissible: !force,
    builder: (dialogContext) {
      String? errorText;
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(force ? '输入登录账号' : '登录账号'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: usernameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: '账号',
                    errorText: errorText,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: '密码',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => obscure = !obscure),
                      icon: Icon(
                        obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: remember,
                  title: const Text('记住密码'),
                  subtitle: const Text('勾选后会安全保存到本机，下次可自动续登'),
                  onChanged: (value) => setState(() => remember = value),
                ),
              ],
            ),
            actions: [
              if (!force)
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
              FilledButton(
                onPressed: () {
                  final username = usernameController.text.trim();
                  final password = passwordController.text;
                  if (username.isEmpty || password.isEmpty) {
                    setState(() => errorText = '请输入完整账号和密码');
                    return;
                  }
                  Navigator.of(dialogContext).pop(
                    LoginCredentialDialogResult(
                      rememberPassword: remember,
                      username: username,
                      password: password,
                    ),
                  );
                },
                child: Text(remember ? '保存并登录' : '登录并同步'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<LoginSemesterSelection?> showLoginSemesterPicker({
  required BuildContext context,
  required String? selectedSemesterCode,
  required List<String> optionLabels,
  required List<String> optionCodes,
}) async {
  final selection = await showModalBottomSheet<Object?>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text(
                '目标学期',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('默认会自动选择教务系统里最新的学期'),
            ),
            RadioGroup<String?>(
              groupValue: selectedSemesterCode,
              onChanged: (value) {
                Navigator.of(sheetContext).pop(value);
              },
              child: Column(
                children: [
                  const RadioListTile<String?>(
                    value: null,
                    title: Text('自动选择最新学期'),
                  ),
                  ...optionCodes.asMap().entries.map(
                    (entry) => RadioListTile<String?>(
                      value: entry.value,
                      title: Text(optionLabels[entry.key]),
                      subtitle: Text(entry.value),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  if (selection == null) return null;
  return LoginSemesterSelection(selection as String?);
}
