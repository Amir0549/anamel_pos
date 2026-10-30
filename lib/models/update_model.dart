class UpdateInfo {
  final String version;
  final String notes;
  final bool mandatory;
  final Map<String, String> downloads;

  const UpdateInfo({
    required this.version,
    required this.notes,
    required this.mandatory,
    required this.downloads,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    final downloadsJson = json['downloads'];

    final downloads = <String, String>{};

    if (downloadsJson is Map) {
      downloadsJson.forEach((key, value) {
        if (key is String && value is String && value.isNotEmpty) {
          downloads[key] = value;
        }
      });
    }

    return UpdateInfo(
      version: json['version'] as String,
      notes: json['notes'] as String? ?? '',
      mandatory: json['mandatory'] as bool? ?? false,
      downloads: downloads,
    );
  }

  String? downloadUrlFor(String operatingSystem) {
    return downloads[operatingSystem];
  }
}
