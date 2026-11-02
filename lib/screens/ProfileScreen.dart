import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../app_colors.dart';
import '../controllers/auth_controller.dart';
import '../controllers/profile_controller.dart';
import '../core/constants.dart';
import '../design_system/widgets/app_button.dart';
import '../design_system/widgets/app_card.dart';
import '../design_system/widgets/section_header.dart';
import '../models/profile.dart';
import '../widgets/common/swr_state_view.dart';
import '../widgets/profile/profile_action_tile.dart';
import '../widgets/profile/profile_info_row.dart';
import '../widgets/profile/upload_progress_dialog.dart';
import 'ChangePasswordScreen.dart';

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
        backgroundColor: isError ? AppColors.error : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showPhotoSheet(Profile profile) {
    final hasPhoto = profile.hasPhoto;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Change Profile Photo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_camera_rounded, color: AppColors.primary, size: 20),
                ),
                title: const Text('Take Photo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                subtitle: const Text('Capture with device camera', style: TextStyle(fontSize: 12)),
                onTap: () => _pickImage(ImageSource.camera),
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.textPrimary, size: 20),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                subtitle: const Text('Select a saved image', style: TextStyle(fontSize: 12)),
                onTap: () => _pickImage(ImageSource.gallery),
              ),
              if (hasPhoto)
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                  ),
                  title: const Text('Remove Photo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.error)),
                  subtitle: const Text('Revert to initial avatar', style: TextStyle(fontSize: 12)),
                  onTap: _removePhoto,
                ),
              const SizedBox(height: 8),
            ],
          ),
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
    } catch (_) {
      _snack('Could not access camera or gallery', isError: true);
    }
  }

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
      _snack('Profile photo updated');
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
      _snack('Profile photo removed');
    } catch (e) {
      _snack('Could not remove photo', isError: true);
    }
  }

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
          final zonesForBarangay = barangay != null
              ? (AppConstants.zonesByBarangay[barangay] ?? AppConstants.defaultZones)
              : <String>[];

          if (zone != null && !zonesForBarangay.contains(zone)) {
            zone = null;
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.borderStrong,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Edit Profile Information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Keep your Muntinlupa residence and contact details updated',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 18),
                  _editField(
                    label: 'Email (Read-only)',
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
                  const SizedBox(height: 16),
                  const Text(
                    'Barangay',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  _dropdown<String>(
                    hint: 'Select your barangay',
                    value: barangay,
                    items: AppConstants.barangays,
                    onChanged: (v) => setSheetState(() {
                      barangay = v;
                      zone = null;
                    }),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Zone / Street',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  if (barangay == null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Text(
                        'Select a barangay first',
                        style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                      ),
                    )
                  else
                    _dropdown<String>(
                      hint: 'Select your zone / street',
                      value: zone,
                      items: zonesForBarangay,
                      onChanged: (v) => setSheetState(() => zone = v),
                    ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: WiseButton(
                      label: 'Save Changes',
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
                          _snack('Profile updated successfully');
                        } catch (e) {
                          if (!mounted) return;
                          _snack(
                            'Update failed: ${e.toString().replaceFirst('Exception: ', '')}',
                            isError: true,
                          );
                        }
                      },
                      fullWidth: true,
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
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        filled: true,
        fillColor: enabled ? AppColors.surfaceVariant : const Color(0xFFF1F5F9),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
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
      hint: Text(hint, style: const TextStyle(fontSize: 13, color: AppColors.textTertiary)),
      items: items
          .map((item) => DropdownMenuItem<T>(value: item, child: Text(item.toString(), style: const TextStyle(fontSize: 14))))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out of your WISE account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await AuthController.instance.logout();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: ListenableBuilder(
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
      ),
    );
  }

  Widget _buildContent(Profile profile) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        _buildIdCard(profile),
        const SizedBox(height: 16),
        const SectionHeader(
          title: 'Account Information',
          subtitle: 'Your registered details and jurisdiction',
        ),
        const SizedBox(height: 8),
        _buildRecordCard(profile),
        const SizedBox(height: 20),
        const SectionHeader(
          title: 'Account Security & Settings',
          subtitle: 'Manage credentials and preferences',
        ),
        const SizedBox(height: 8),
        ProfileActionTile(
          icon: Icons.edit_rounded,
          title: 'Edit Profile Information',
          subtitle: 'Update your display name, phone, and address',
          onTap: () => _showEditSheet(profile),
        ),
        const SizedBox(height: 8),
        ProfileActionTile(
          icon: Icons.lock_outline_rounded,
          title: 'Change Password',
          subtitle: 'Update your security credentials',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
          ),
        ),
        const SizedBox(height: 24),
        WiseOutlinedButton(
          label: 'Log Out of Account',
          icon: Icons.logout_rounded,
          onPressed: _confirmLogout,
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _buildIdCard(Profile profile) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      color: Colors.white,
      borderColor: AppColors.border,
      borderWidth: 1,
      elevation: 1,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          _buildAvatar(profile),
          const SizedBox(height: 14),
          Text(
            profile.fullname.isNotEmpty ? profile.fullname : 'Resident',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            profile.addressLine.isNotEmpty ? profile.addressLine : 'Muntinlupa City',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Text(
              profile.roleLabel,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(Profile profile) {
    final imageUrl = _controller.imageUrl(profile.profileImage);
    final initial = profile.fullname.trim().isNotEmpty ? profile.fullname.trim()[0].toUpperCase() : 'U';

    return Stack(
      children: [
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => _avatarPlaceholder(initial),
                    errorWidget: (context, url, error) => _avatarPlaceholder(initial),
                  )
                : _avatarPlaceholder(initial),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: () => _showPhotoSheet(profile),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6),
                ],
              ),
              child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _avatarPlaceholder(String initial) {
    return Container(
      color: AppColors.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 32,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildRecordCard(Profile profile) {
    return AppCard(
      padding: EdgeInsets.zero,
      color: Colors.white,
      borderColor: AppColors.border,
      borderWidth: 1,
      elevation: 1,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          ProfileInfoRow(icon: Icons.mail_outline_rounded, label: 'Email Address', value: profile.email),
          ProfileInfoRow(
            icon: Icons.phone_outlined,
            label: 'Contact Number',
            value: profile.phone.isEmpty ? 'Not set' : profile.phone,
          ),
          ProfileInfoRow(
            icon: Icons.location_on_outlined,
            label: 'Registered Barangay',
            value: profile.barangay.isEmpty ? 'Not set' : profile.barangay,
          ),
          ProfileInfoRow(
            icon: Icons.map_outlined,
            label: 'Assigned Zone / Street',
            value: profile.zone.isEmpty ? 'Not set' : profile.zone,
            isLast: true,
          ),
        ],
      ),
    );
  }
}
