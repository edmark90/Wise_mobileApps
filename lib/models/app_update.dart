class AppUpdate {
  final int id;
  final String version;
  final int versionCode;
  final String title;
  final String? releaseNotes;
  final String apkUrl;
  final bool isForce;

  AppUpdate({
    required this.id,
    required this.version,
    required this.versionCode,
    required this.title,
    this.releaseNotes,
    required this.apkUrl,
    required this.isForce,
  });

  factory AppUpdate.fromJson(Map<String, dynamic> json) {
    return AppUpdate(
      id: json['id'] ?? 0,
      version: json['version'] ?? '',
      versionCode: json['version_code'] ?? 0,
      title: json['title'] ?? '',
      releaseNotes: json['release_notes'],
      apkUrl: json['apk_url'] ?? '',
      isForce: json['is_force'] ?? false,
    );
  }
}

class LatestUpdateResult {
  final bool updateAvailable;
  final AppUpdate? latest;
  final int? currentVersionCode;

  LatestUpdateResult({
    required this.updateAvailable,
    this.latest,
    this.currentVersionCode,
  });

  factory LatestUpdateResult.fromJson(Map<String, dynamic> json) {
    return LatestUpdateResult(
      updateAvailable: json['update_available'] ?? false,
      latest: json['latest'] != null ? AppUpdate.fromJson(json['latest']) : null,
      currentVersionCode: json['current_version_code'],
    );
  }
}