import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_colors.dart';
import '../controllers/waste_guide_controller.dart';
import '../models/ai_waste.dart';
import '../models/waste_bin.dart';
import '../services/ai_service.dart';
import 'MainScreen.dart';

/// AI Waste Input — capture or upload a photo of waste and let the backend AI
/// classify it into one of the 5 standard categories:
/// 1. Biodegradable Waste
/// 2. Electronic Waste (E-Waste)
/// 3. Hazardous Waste
/// 4. Recyclable Waste
/// 5. Residual (Non-Recyclable) Waste
class AiWasteInputScreen extends StatefulWidget {
  const AiWasteInputScreen({super.key});

  @override
  State<AiWasteInputScreen> createState() => _AiWasteInputScreenState();
}

class _AiWasteInputScreenState extends State<AiWasteInputScreen> {
  final ImagePicker _picker = ImagePicker();

  // Capture + prediction state
  Uint8List? _imageBytes;
  String? _imageName;
  bool _predicting = false;
  AiWaste? _result;
  Object? _error;

  // Backend health + model metadata
  Map<String, dynamic>? _health;
  Map<String, dynamic>? _modelInfo;
  bool _metaLoading = true;
  Object? _metaError;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    setState(() {
      _metaLoading = true;
      _metaError = null;
    });
    try {
      final results = await Future.wait<Map<String, dynamic>>([
        AiService.instance.health(),
        AiService.instance.modelInfo(),
      ]);
      if (!mounted) return;
      setState(() {
        _health = results[0];
        _modelInfo = results[1];
        _metaLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _metaError = e;
        _metaLoading = false;
      });
    }
  }

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
  // Capture
  // ---------------------------------------------------------------------

  void _showPickSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
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
              subtitle: const Text('Use device camera', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.lightBg,
                child: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              ),
              title: const Text('Choose from Gallery', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              subtitle: const Text('Select a saved image', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.gallery);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.close_rounded, color: Colors.grey),
              title: const Text(
                'Cancel',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey),
              ),
              onTap: () => Navigator.pop(sheetContext),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1600,
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      // Derive the file extension from the picker path so we upload the
      // correct MIME type (e.g. .png from gallery, .jpg from camera).
      final ext = picked.path.isNotEmpty ? picked.path.split('.').last.toLowerCase() : 'jpg';
      final safeExt = ['jpg', 'jpeg', 'png', 'webp'].contains(ext) ? ext : 'jpg';
      setState(() {
        _imageBytes = bytes;
        _imageName = 'waste_${DateTime.now().millisecondsSinceEpoch}.$safeExt';
        _result = null;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      _snack('Cannot access camera or gallery', isError: true);
    }
  }

  void _reset() {
    setState(() {
      _imageBytes = null;
      _imageName = null;
      _result = null;
      _error = null;
    });
  }

  // ---------------------------------------------------------------------
  // Prediction
  // ---------------------------------------------------------------------

  Future<void> _classify() async {
    final bytes = _imageBytes;
    if (bytes == null || _predicting) return;

    setState(() {
      _predicting = true;
      _error = null;
      _result = null;
    });

    try {
      final result = await AiService.instance.predict(
        bytes,
        filename: _imageName ?? 'waste.jpg',
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _predicting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _predicting = false;
      });
    }
  }

  // ---------------------------------------------------------------------
  // Metadata Helpers
  // ---------------------------------------------------------------------

  bool get _isHealthy {
    final h = _health;
    if (h == null) return false;
    final raw = h['status'] ?? h['health'] ?? h['database'] ?? h['model'] ?? '';
    final status = raw.toString().toLowerCase();
    return status.contains('ok') || status.contains('healthy') || status.contains('up') || status == 'true';
  }

  String? get _backbone {
    final v = (_modelInfo?['backbone'] ?? '').toString();
    return v.isEmpty ? null : v;
  }

  String? get _inputSize {
    final v = _modelInfo?['inputs'] ?? _modelInfo?['input_size'];
    if (v == null) return null;
    if (v is String || v is num) {
      final s = v.toString();
      return s.isEmpty ? null : s;
    }
    if (v is List && v.isNotEmpty) {
      if (v.every((e) => e is num)) return v.map((e) => e.toString()).join('×');
      return '${v.length} inputs';
    }
    if (v is Map && v.isNotEmpty) return '${v.length} inputs';
    return null;
  }

  int? get _classCount {
    final classes = _modelInfo?['classes'];
    if (classes is Map) return classes.length;
    if (classes is List) return classes.length;
    return null;
  }

  List<String> _classNames() {
    final classes = _modelInfo?['classes'];
    if (classes is Map) {
      return classes.values.map((v) => v.toString()).toList();
    }
    if (classes is List) {
      return classes.map((v) => v.toString()).toList();
    }
    return const [];
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetaStatus(),
            const SizedBox(height: 20),
            if (_imageBytes == null)
              _buildCaptureCard()
            else ...[
              _buildPreviewCard(),
              const SizedBox(height: 16),
              _buildClassifyButton(),
            ],
            if (_predicting) ...[
              const SizedBox(height: 16),
              _buildProgressCard(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              _buildErrorCard(),
            ],
            if (_result != null) ...[
              const SizedBox(height: 20),
              _buildResultHeader(),
              const SizedBox(height: 12),
              _buildResultCard(_result!),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Backend status strip ─────────────────────────────────────────
  Widget _buildMetaStatus() {
    if (_metaLoading) {
      return _statusPill(
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
            SizedBox(width: 8),
            Text('Checking AI service…', style: TextStyle(fontSize: 12)),
          ],
        ),
      );
    }
    if (_metaError != null) {
      return _statusPill(
        color: AppColors.errorContainer,
        borderColor: AppColors.error.withValues(alpha: 0.3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 14, color: AppColors.error),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Just wait, starting the server on Render…',
                style: const TextStyle(fontSize: 11.5, color: AppColors.onErrorContainer, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _loadMeta,
              child: const Text('Retry', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.error)),
            ),
          ],
        ),
      );
    }

    final classes = _classNames();
    final count = _classCount;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _statusPill(
          color: _isHealthy ? AppColors.successContainer : AppColors.errorContainer,
          borderColor: _isHealthy ? AppColors.success.withValues(alpha: 0.3) : AppColors.error.withValues(alpha: 0.3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isHealthy ? Icons.check_circle_rounded : Icons.error_rounded,
                size: 14,
                color: _isHealthy ? AppColors.onSuccessContainer : AppColors.error,
              ),
              const SizedBox(width: 6),
              Text(
                _isHealthy ? 'AI Service Online' : 'AI Service Offline',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _isHealthy ? AppColors.onSuccessContainer : AppColors.onErrorContainer,
                ),
              ),
            ],
          ),
        ),
        if (_backbone != null)
          _statusPill(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.memory_rounded, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text('Model: $_backbone', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        if (count != null)
          _statusPill(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.category_rounded, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text('$count Categories', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        if (_inputSize != null)
          _statusPill(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.aspect_ratio_rounded, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text('Input: $_inputSize', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        if (classes.isNotEmpty)
          GestureDetector(
            onTap: () => _showClassesSheet(classes),
            child: _statusPill(
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text('View Classes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _statusPill({required Widget child, Color? color, Color? borderColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color ?? AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: borderColor ?? AppColors.border),
      ),
      child: child,
    );
  }

  void _showClassesSheet(List<String> classes) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI Waste Classification Categories',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              const Text(
                'Standard waste classification categories recognized by the model',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ...List.generate(classes.length, (i) {
                final name = classes[i];
                final bin = WasteBin.forCategory(name);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bin.container,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: bin.color.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Text(bin.emoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: bin.color,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            bin.name,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Capture card ────────────────────────────────────────────────
  Widget _buildCaptureCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8), Color(0xFF1E3A8A)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -10,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
                  ),
                  child: const Icon(Icons.photo_camera_front_rounded, color: Colors.white, size: 44),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Classify Waste',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Capture or upload a photo of waste to automatically identify its category and proper disposal bin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, height: 1.5, color: Colors.white.withValues(alpha: 0.85)),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: _captureButton(
                        icon: Icons.photo_camera_rounded,
                        label: 'Camera',
                        onTap: () => _pickImage(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _captureButton(
                        icon: Icons.photo_library_rounded,
                        label: 'Gallery',
                        filled: true,
                        onTap: () => _pickImage(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _captureButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: filled ? Colors.white : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: filled ? null : Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: filled ? AppColors.primary : Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: filled ? AppColors.primary : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scrimButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  // ─── Preview + classify ──────────────────────────────────────────
  Widget _buildPreviewCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.shadowMedium, blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.memory(_imageBytes!, fit: BoxFit.cover),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 40, 16, 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Ready to Classify',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    _scrimButton(icon: Icons.swap_horiz_rounded, label: 'Change', onTap: _showPickSheet),
                    const SizedBox(width: 8),
                    _scrimButton(icon: Icons.refresh_rounded, label: 'New', onTap: _reset),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassifyButton() {
    final enabled = _imageBytes != null && !_predicting;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: enabled ? _classify : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.surfaceContainerHigh,
          foregroundColor: Colors.white,
          disabledForegroundColor: AppColors.textTertiary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: const Icon(Icons.auto_awesome_rounded, size: 20),
        label: const Text(
          'Classify Waste',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'AI is analyzing the image…',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onPrimaryContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    final message = _error.toString().replaceFirst('Exception: ', '');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cannot classify image',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.onErrorContainer),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.onErrorContainer),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _classify,
                  child: const Text(
                    'Try Again',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.error),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Result ──────────────────────────────────────────────────────
  Widget _buildResultHeader() {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.successContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.verified_rounded, size: 20, color: AppColors.onSuccessContainer),
        ),
        const SizedBox(width: 10),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Classification Result',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            Text(
              'Here is the recognized waste category',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultCard(AiWaste result) {
    final bin = result.bin;
    final bandColor = result.reportedBinColor;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: AppColors.shadowMedium, blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Color band
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [bandColor, Color.lerp(bandColor, Colors.black, 0.25)!],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: Text(result.icon.isEmpty ? bin.emoji : result.icon, style: const TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.category.isEmpty ? bin.name : result.category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Dispose in ${bin.name}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.9)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.name.isEmpty ? 'Recognized Waste' : result.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),
                // Confidence
                Row(
                  children: [
                    const Text(
                      'AI Confidence',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                    ),
                    const Spacer(),
                    Text(
                      '${result.confidencePercent}%',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: result.confidence.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceContainer,
                    valueColor: AlwaysStoppedAnimation<Color>(bandColor),
                  ),
                ),
                const SizedBox(height: 14),
                // Recyclable chip + bin chip
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: result.recyclable ? AppColors.successContainer : AppColors.errorContainer,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            result.recyclable ? Icons.recycling_rounded : Icons.block_rounded,
                            size: 13,
                            color: result.recyclable ? AppColors.onSuccessContainer : AppColors.onErrorContainer,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            result.recyclable ? 'Recyclable' : 'Non-Recyclable',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: result.recyclable ? AppColors.onSuccessContainer : AppColors.onErrorContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: bin.container,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(bin.icon, size: 13, color: bin.color),
                          const SizedBox(width: 4),
                          Text(
                            'Deposit in ${bin.name}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: bin.color),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Save to Waste Guide Action Button
                ListenableBuilder(
                  listenable: WasteGuideController.instance,
                  builder: (context, _) {
                    final savedCount = WasteGuideController.instance
                        .getSavedCountForCategory(result.category);
                    final alreadySaved = savedCount > 0;
                    return SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final bytes = _imageBytes;
                          final name = _imageName;
                          if (bytes == null || name == null) return;
                          await WasteGuideController.instance
                              .saveAiResult(result, imageBytes: bytes, imageName: name);
                          if (!mounted) return;
                          _snack('Saved ${result.category} guide!');
                          // Navigate to Waste Guide tab (index 2) then switch to Saved sub-tab
                          WasteGuideController.instance
                              .setSelectedCategory(result.category);
                          MainScreenScope.of(context)?.selectTab(2);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: alreadySaved
                              ? AppColors.successContainer
                              : AppColors.primary,
                          foregroundColor: alreadySaved
                              ? AppColors.onSuccessContainer
                              : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: Icon(
                          alreadySaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_add_rounded,
                          size: 16,
                        ),
                        label: Text(
                          alreadySaved ? 'Save Another ($savedCount saved)' : 'Save Guide',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: TextButton.icon(
                    onPressed: _reset,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    icon: const Icon(Icons.add_a_photo_rounded, size: 16),
                    label: const Text(
                      'Classify Another Waste',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
