class SemesterOption {
  const SemesterOption({required this.code, required this.name});

  final String code;
  final String name;

  String get normalizedCode => code.trim();
  String get normalizedName => name.trim();

  bool get isValid => RegExp(r'^\d{5}$').hasMatch(normalizedCode);

  SemesterOption copyWith({String? code, String? name}) {
    return SemesterOption(code: code ?? this.code, name: name ?? this.name);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'code': normalizedCode, 'name': normalizedName};
  }

  factory SemesterOption.fromJson(Map<String, dynamic> json) {
    return SemesterOption(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SemesterOption &&
        other.normalizedCode == normalizedCode &&
        other.normalizedName == normalizedName;
  }

  @override
  int get hashCode => Object.hash(normalizedCode, normalizedName);
}
