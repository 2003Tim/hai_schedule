bool looksLikeSemesterCode(String value) {
  return RegExp(r'^\d{4}[12]$').hasMatch(value);
}

String formatSemesterCode(String code) {
  if (!looksLikeSemesterCode(code)) return code;
  final startYear = int.parse(code.substring(0, 4));
  final endYear = startYear + 1;
  final term =
      code.endsWith('1')
          ? '\u7b2c\u4e00\u5b66\u671f'
          : '\u7b2c\u4e8c\u5b66\u671f';
  return '$startYear-$endYear $term';
}

String formatOptionalSemesterCode(
  String? code, {
  String emptyLabel = '\u672a\u8bbe\u7f6e\u5b66\u671f',
}) {
  if (code == null || code.isEmpty) return emptyLabel;
  return formatSemesterCode(code);
}
