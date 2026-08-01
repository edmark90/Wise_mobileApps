import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../app_colors.dart';
import '../controllers/profile_controller.dart';
import '../core/constants.dart';
import '../models/profile.dart';
import '../widgets/common/swr_state_view.dart';
import '../widgets/profile/profile_action_tile.dart';
import '../widgets/profile/profile_info_row.dart';
import '../widgets/profile/upload_progress_dialog.dart';
import 'ChangePasswordScreen.dart';

/// Profile view (MVC View). All data + mutations go through
/// [ProfileController], which loads via the SWR cache — so the profile
/// appears instantly on return visits while a background refresh runs.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileController _controller = ProfileController.instance;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  Future<void> _refresh() => _controller.load(force: true);

  void _snack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFC62828) : AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Photo
  // ---------------------------------------------------------------------

  void _showPhotoSheet(Profile profile) {
    final hasPhoto = profile.hasPhoto;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.lightBg,
                child: const Icon(Icons.photo_camera_rounded, color: AppColors.primary),
              ),
              title: const Text('Take Photo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              onTap: () => _pickImage(ImageSource.camera),
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.lightBg,
                child: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              ),
              title: const Text('Choose from Gallery', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              onTap: () => _pickImage(ImageSource.gallery),
            ),
            if (hasPhoto)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFFEF2F2),
                  child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                ),
                title: const Text(
                  'Remove Current Photo',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
                ),
                onTap: _removePhoto,
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.close_rounded, color: Colors.grey),
              title: const Text(
                'Cancel',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey),
              ),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context);
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1200,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final processed = _processImage(bytes);
      if (processed == null) {
        _snack('Could not process the image', isError: true);
        return;
      }
      await _uploadPhoto(processed, filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
    } catch (e) {
      _snack('Could not access the camera or gallery', isError: true);
    }
  }

  // Center-crop to a square, resize to 512x512, then compress as JPG.
  Uint8List? _processImage(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      final side = math.min(decoded.width, decoded.height);
      final cropped = img.copyCrop(
        decoded,
        x: (decoded.width - side) ~/ 2,
        y: (decoded.height - side) ~/ 2,
        width: side,
        height: side,
      );
      final resized = img.copyResize(
        cropped,
        width: 512,
        height: 512,
        interpolation: img.Interpolation.average,
      );
      return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
    } catch (_) {
      return null;
    }
  }

  Future<void> _uploadPhoto(Uint8List bytes, {required String filename}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const UploadProgressDialog(),
    );
    try {
      await _controller.uploadPhoto(bytes, filename: filename);
      if (!mounted) return;
      Navigator.of(context).pop();
      _snack('Profile picture updated');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _snack('Upload failed: ${e.toString().replaceFirst('Exception: ', '')}', isError: true);
    }
  }

  Future<void> _removePhoto() async {
    Navigator.pop(context);
    try {
      await _controller.removePhoto();
      _snack('Profile picture removed');
    } catch (e) {
      _snack('Could not remove photo', isError: true);
    }
  }

  // ---------------------------------------------------------------------
  // Edit profile sheet
  // ---------------------------------------------------------------------

  void _showEditSheet(Profile profile) {
    final fullnameController = TextEditingController(text: profile.fullname);
    final phoneController = TextEditingController(text: profile.phone);
    String? barangay = profile.barangay.isEmpty ? null : profile.barangay;
    String? zone = profile.zone.isEmpty ? null : profile.zone;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Edit Profile',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Email cannot be changed.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 18),
                  _editField(
                    label: 'Email',
                    controller: TextEditingController(text: profile.email),
                    enabled: false,
                  ),
                  const SizedBox(height: 12),
                  _editField(label: 'Full Name', controller: fullnameController),
                  const SizedBox(height: 12),
                  _editField(
                    label: 'Phone Number',
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Barangay',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 8),
                  _dropdown<String>(
                    hint: 'Select barangay',
                    value: barangay,
                    items: AppConstants.barangays,
                    onChanged: (v) => setSheetState(() => barangay = v),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Zone',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 8),
                  _dropdown<String>(
                    hint: 'Select zone',
                    value: zone,
                    items: AppConstants.zones,
                    onChanged: (v) => setSheetState(() => zone = v),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await _controller.update(
                            fullname: fullnameController.text.trim(),
                            phone: phoneController.text.trim(),
                            barangay: barangay,
                            zone: zone,
                          );
                          if (!sheetContext.mounted) return;
                          Navigator.of(sheetContext).pop();
                          if (!mounted) return;
                          _snack('Profile updated');
                        } catch (e) {
                          if (!mounted) return;
                          _snack(
                            'Update failed: ${e.toString().replaceFirst('Exception: ', '')}',
                            isError: true,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Save Changes',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _editField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15, color: Color(0xFF0F172A)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600]),
        filled: true,
        fillColor: enabled ? AppColors.lightBg : Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required String hint,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      hint: Text(hint, style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
      items: items
          .map((item) => DropdownMenuItem<T>(value: item, child: Text(item.toString(), style: const TextStyle(fontSize: 14))))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.lightBg,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final state = _controller.state;
        if (state == null) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.primary,
          child: SwrStateView<Profile>(
            state: state,
            onRetry: _refresh,
            builder: (context, profile) => _buildContent(profile),
          ),
        );
      },
    );
  }

  Widget _buildContent(Profile profile) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _buildIdCard(profile),
        const SizedBox(height: 16),
        _buildRecordCard(profile),
        const SizedBox(height: 16),
        ProfileActionTile(
          icon: Icons.edit_rounded,
          title: 'Edit Profile',
          subtitle: 'Update your name, phone, and address',
          onTap: () => _showEditSheet(profile),
        ),
        const SizedBox(height: 8),
        ProfileActionTile(
          icon: Icons.lock_outline_rounded,
          title: 'Change Password',
          subtitle: 'Update your account password',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildIdCard(Profile profile) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          children: [
            _buildAvatar(profile),
            const SizedBox(height: 16),
            Text(
              profile.fullname,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              profile.addressLine,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                profile.roleLabel,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(Profile profile) {
    final imageUrl = _controller.imageUrl(profile.profileImage);
    return Stack(
      children: [
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: ClipOval(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      key: ValueKey(imageUrl),
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => _avatarPlaceholder(),
                      errorWidget: (context, url, error) => _avatarPlaceholder(),
                    )
                  : _avatarPlaceholder(key: const ValueKey('placeholder')),
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: () => _showPhotoSheet(profile),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 2),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6)],
              ),
              child: const Icon(Icons.photo_camera_rounded, color: AppColors.primary, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _avatarPlaceholder({Key? key}) {
    return Container(
      key: key,
      color: AppColors.lightBg,
      child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 56),
    );
  }

  Widget _buildRecordCard(Profile profile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          ProfileInfoRow(icon: Icons.mail_outline_rounded, label: 'Email', value: profile.email),
          ProfileInfoRow(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: profile.phone.isEmpty ? '—' : profile.phone,
          ),
          ProfileInfoRow(
            icon: Icons.location_on_outlined,
            label: 'Barangay',
            value: profile.barangay.isEmpty ? '—' : profile.barangay,
          ),
          ProfileInfoRow(
            icon: Icons.map_outlined,
            label: 'Zone',
            value: profile.zone.isEmpty ? '—' : profile.zone,
            isLast: true,
          ),
        ],
      ),
    );
  }
}
