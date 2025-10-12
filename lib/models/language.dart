class Language {
  final int id;
  final String name;
  final String code;

  Language({required this.id, required this.name, required this.code});

  factory Language.fromJson(Map<String, dynamic> json) {
    return Language(
      id: json['id'],
      name: json['name'],
      code: json['code'],
    );
  }
}