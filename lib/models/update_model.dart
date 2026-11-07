class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String notes;
  final bool mandatory;

  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.notes,
    required this.mandatory,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] as String? ?? '',
      downloadUrl: json['download_url'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      mandatory: json['mandatory'] as bool? ?? false,
    );
  }
}
