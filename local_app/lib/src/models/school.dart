class School {
  School({
    required this.id,
    required this.name,
    required this.code,
    required this.supportsOfficialApi,
  });

  final String id;
  final String name;
  final String code;
  final bool supportsOfficialApi;

  factory School.fromJson(Map<String, dynamic> json) {
    return School(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      supportsOfficialApi: json['supportsOfficialApi'] as bool,
    );
  }
}
