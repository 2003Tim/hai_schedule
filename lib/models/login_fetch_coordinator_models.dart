class LoginFetchUiStateUpdate {
  const LoginFetchUiStateUpdate({
    this.isFetching,
    this.pendingAutofill,
    this.statusText,
  });

  final bool? isFetching;
  final bool? pendingAutofill;
  final String? statusText;
}

class LoginAutofillStateResolution {
  const LoginAutofillStateResolution({
    required this.statusText,
    this.stopAutofillLoop = false,
    this.clearPendingAutofill = false,
  });

  final String statusText;
  final bool stopAutofillLoop;
  final bool clearPendingAutofill;
}
