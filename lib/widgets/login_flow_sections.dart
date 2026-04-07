import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hai_schedule/services/auth_credentials_service.dart';
import 'package:hai_schedule/widgets/adaptive_layout.dart';

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

enum _LoginFlowAppBarAction {
  manageCredential,
  clearCredential,
  pickSemester,
  manualFetch,
}

class LoginRememberPasswordTile extends StatelessWidget {
  const LoginRememberPasswordTile({
    super.key,
    required this.isFetching,
    required this.rememberPassword,
    required this.savedCredential,
    required this.onRememberPasswordChanged,
    required this.onManageCredential,
  });

  final bool isFetching;
  final bool rememberPassword;
  final SavedPortalCredential? savedCredential;
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
          savedCredential == null
              ? '保存后可自动填充登录页，也更方便切换账号'
              : '当前账号：${savedCredential!.maskedUsername}',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.66),
          ),
        ),
        trailing: TextButton(
          onPressed: isFetching ? null : () => unawaited(onManageCredential()),
          child: Text(savedCredential == null ? '填写账号' : '切换账号'),
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
    this.activeBackgroundColor,
    this.idleBackgroundColor,
    this.textStyle,
  });

  final bool isFetching;
  final String statusText;
  final String? selectedSemesterCode;
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
                  : '目标学期 $selectedSemesterCode · $statusText',
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
    required this.savedCredential,
    required this.selectedSemesterCode,
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
  final SavedPortalCredential? savedCredential;
  final String? selectedSemesterCode;
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
    final isCompactActions = MediaQuery.sizeOf(context).width < 560;

    return Scaffold(
      appBar: AppBar(
        title: const Text('登录教务系统'),
        actions: [
          if (!isFetching && !isCompactActions)
            IconButton(
              key: const ValueKey('loginFlowManageCredentialAction'),
              tooltip: '账号与密码',
              onPressed: () => unawaited(onOpenCredentialEditor()),
              icon: const Icon(Icons.manage_accounts_outlined),
            ),
          if (!isFetching && !isCompactActions && savedCredential != null)
            IconButton(
              key: const ValueKey('loginFlowClearCredentialAction'),
              tooltip: '清除已保存账号',
              onPressed: () => unawaited(onClearSavedCredential()),
              icon: const Icon(Icons.logout_rounded),
            ),
          if (!isFetching && !isCompactActions)
            TextButton.icon(
              key: const ValueKey('loginFlowPickSemesterAction'),
              onPressed: () => unawaited(onPickTargetSemester()),
              icon: const Icon(Icons.school_outlined, size: 18),
              label: Text(
                selectedSemesterCode == null ? '自动学期' : selectedSemesterCode!,
              ),
            ),
          if (canManualFetch && !isFetching && !isCompactActions)
            TextButton.icon(
              key: const ValueKey('loginFlowManualFetchAction'),
              onPressed: () => unawaited(onAutoFetch()),
              icon: const Icon(Icons.download, size: 18),
              label: const Text('手动抓取'),
            ),
          if (!isFetching && isCompactActions)
            PopupMenuButton<_LoginFlowAppBarAction>(
              key: const ValueKey('loginFlowOverflowMenu'),
              tooltip: '更多操作',
              onSelected: (action) {
                switch (action) {
                  case _LoginFlowAppBarAction.manageCredential:
                    unawaited(onOpenCredentialEditor());
                    break;
                  case _LoginFlowAppBarAction.clearCredential:
                    unawaited(onClearSavedCredential());
                    break;
                  case _LoginFlowAppBarAction.pickSemester:
                    unawaited(onPickTargetSemester());
                    break;
                  case _LoginFlowAppBarAction.manualFetch:
                    unawaited(onAutoFetch());
                    break;
                }
              },
              itemBuilder: (context) {
                return [
                  const PopupMenuItem<_LoginFlowAppBarAction>(
                    value: _LoginFlowAppBarAction.manageCredential,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.manage_accounts_outlined),
                      title: Text('账号与密码'),
                    ),
                  ),
                  if (savedCredential != null)
                    const PopupMenuItem<_LoginFlowAppBarAction>(
                      value: _LoginFlowAppBarAction.clearCredential,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.logout_rounded),
                        title: Text('清除已保存账号'),
                      ),
                    ),
                  PopupMenuItem<_LoginFlowAppBarAction>(
                    value: _LoginFlowAppBarAction.pickSemester,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.school_outlined),
                      title: const Text('目标学期'),
                      subtitle: Text(
                        selectedSemesterCode == null
                            ? '自动学期'
                            : selectedSemesterCode!,
                      ),
                    ),
                  ),
                  if (canManualFetch)
                    const PopupMenuItem<_LoginFlowAppBarAction>(
                      value: _LoginFlowAppBarAction.manualFetch,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.download_rounded),
                        title: Text('手动抓取'),
                      ),
                    ),
                ];
              },
            ),
        ],
      ),
      body: Column(
        children: [
          LoginRememberPasswordTile(
            isFetching: isFetching,
            rememberPassword: rememberPassword,
            savedCredential: savedCredential,
            onRememberPasswordChanged: onRememberPasswordChanged,
            onManageCredential: onOpenCredentialEditor,
          ),
          LoginStatusBanner(
            isFetching: isFetching,
            statusText: statusText,
            selectedSemesterCode: selectedSemesterCode,
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
  required SavedPortalCredential? savedCredential,
  required bool rememberPassword,
  bool force = false,
}) async {
  final usernameController = TextEditingController(
    text: savedCredential?.username ?? '',
  );
  final passwordController = TextEditingController(
    text: savedCredential?.password ?? '',
  );
  bool remember = rememberPassword || force;
  bool obscure = true;

  try {
    return await showDialog<LoginCredentialDialogResult>(
      context: context,
      barrierDismissible: !force,
      builder: (dialogContext) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              scrollable: true,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              title: Text(force ? '保存登录账号' : '账号与密码'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
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
                      subtitle: const Text('用于自动填充登录页和后续切换账号'),
                      onChanged: (value) => setState(() => remember = value),
                    ),
                  ],
                ),
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
                    if (remember && (username.isEmpty || password.isEmpty)) {
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
                  child: Text(remember ? '保存并填充' : '仅关闭记住密码'),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    usernameController.dispose();
    passwordController.dispose();
  }
}

const _manualSemesterEntry = Object();

Future<LoginSemesterSelection?> showLoginSemesterPicker({
  required BuildContext context,
  required String? selectedSemesterCode,
  required List<String> sortedCodes,
  required String Function(String code) formatSemesterCode,
  required bool Function(String value) looksLikeSemesterCode,
}) async {
  final selection = await showModalBottomSheet<Object?>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return AdaptiveSheet(
        maxWidth: 680,
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: ListView(
              shrinkWrap: true,
              children: [
                const ListTile(
                  title: Text(
                    '目标学期',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('不选择时，将自动检测教务页面当前学期'),
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
                        title: Text('自动检测当前学期'),
                      ),
                      ...sortedCodes.map(
                        (code) => RadioListTile<String?>(
                          value: code,
                          title: Text(formatSemesterCode(code)),
                          subtitle: Text(code),
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('手动输入学期代码'),
                  subtitle: const Text('例如：20251 或 20252'),
                  onTap:
                      () =>
                          Navigator.of(sheetContext).pop(_manualSemesterEntry),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  if (selection == null) return null;
  if (identical(selection, _manualSemesterEntry)) {
    if (!context.mounted) return null;
    final customCode = await showCustomSemesterCodeDialog(
      context: context,
      initialValue: selectedSemesterCode,
      looksLikeSemesterCode: looksLikeSemesterCode,
    );
    if (customCode == null) return null;
    return LoginSemesterSelection(customCode);
  }

  return LoginSemesterSelection(selection as String?);
}

Future<String?> showCustomSemesterCodeDialog({
  required BuildContext context,
  required String? initialValue,
  required bool Function(String value) looksLikeSemesterCode,
}) async {
  final controller = TextEditingController(text: initialValue ?? '');
  try {
    return await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              scrollable: true,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              title: const Text('手动输入学期代码'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: '学期代码',
                    hintText: '例如：20251',
                    errorText: errorText,
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    final text = controller.text.trim();
                    if (!looksLikeSemesterCode(text)) {
                      setState(() => errorText = '请输入 5 位学期代码，例如 20251');
                      return;
                    }
                    Navigator.of(dialogContext).pop(text);
                  },
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    controller.dispose();
  }
}
