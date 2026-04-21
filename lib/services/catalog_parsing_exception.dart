class CatalogParsingException implements Exception {
  static const defaultMessage = '未能从教务系统解析到学期目录';

  final String message;

  const CatalogParsingException([this.message = defaultMessage]);

  @override
  String toString() => message;
}
