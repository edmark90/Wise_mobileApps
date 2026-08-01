import '../core/network/api_client.dart';
import '../models/profile.dart';

/// REST access to the current user's profile.
class ProfileService {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  String get profileImageBaseUrl => ApiClient.staticBaseUrl;

  /// Build an absolute URL for a profile image path returned by the API.
  String profileImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    return '$profileImageBaseUrl/$path';
  }

  Future<Profile> getProfile() async {
    final response = await ApiClient.instance.get('/users/profile');
    final data = ApiClient.instance.decode(response, fallback: 'Failed to load profile');
    return Profile.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<Profile> updateProfile({
    String? fullname,
    String? phone,
    String? barangay,
    String? zone,
  }) async {
    final response = await ApiClient.instance.put(
      '/users/profile',
      body: {
        'fullname': fullname,
        'phone': phone,
        'barangay': barangay,
        'zone': zone,
      },
    );
    final data = ApiClient.instance.decode(response, fallback: 'Failed to update profile');
    return Profile.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Upload a profile picture and return the new `profile_image` path.
  Future<String> uploadProfilePhoto(List<int> bytes, {required String filename}) async {
    final response = await ApiClient.instance.multipart(
      '/users/profile/upload-photo',
      field: 'file',
      bytes: bytes,
      filename: filename,
    );
    final data = ApiClient.instance.decode(response, fallback: 'Upload failed');
    return (data['profile_image'] ?? '').toString();
  }

  Future<void> removeProfilePhoto() async {
    final response = await ApiClient.instance.delete('/users/profile/remove-photo');
    ApiClient.instance.decode(response, fallback: 'Failed to remove photo');
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final response = await ApiClient.instance.post('/users/profile/change-password', body: {
      'current_password': currentPassword,
      'new_password': newPassword,
      'confirm_password': confirmPassword,
    });
    ApiClient.instance.decode(response, fallback: 'Failed to change password');
  }
}
