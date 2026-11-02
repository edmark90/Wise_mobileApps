import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_colors.dart';
import '../controllers/waste_guide_controller.dart';
import '../design_system/widgets/app_button.dart';
import '../design_system/widgets/app_card.dart';
import '../models/ai_waste.dart';
import '../models/waste_bin.dart';
import '../models/waste_guide.dart';
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

  Uint8List? _imageBytes;
  String? _imageName;
  bool _predicting = false;
  AiWaste? _result;
  Object? _error;

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

    int attempts = 0;
    const maxAttempts = 3;
    const retryDelay = Duration(seconds: 5);

    while (attempts < maxAttempts) {
      attempts++;
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
        return;
      } catch (e) {
        if (!mounted) return;
        if (attempts < maxAttempts) {
          await Future.delayed(retryDelay);
          continue;
        }
        setState(() {
          _metaError = e;
          _metaLoading = false;
        });
      }
    }
  }

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

  void _showPickSheet() {
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
                  'Select Image Source',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
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
                subtitle: const Text('Use device camera to photograph waste', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickImage(ImageSource.camera);
                },
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
                subtitle: const Text('Select a saved photo from your device', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetaStatus(),
            const SizedBox(height: 16),
            if (_imageBytes == null)
              _buildCaptureCard()
            else ...[
              _buildPreviewCard(),
              const SizedBox(height: 14),
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
              _buildResultCard(_result!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetaStatus() {
    if (_metaLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
            SizedBox(width: 8),
            Text(
              'Connecting to AI service…',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    if (_metaError != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.warningContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.onWarningContainer),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'AI server is warming up on Render. Classification will connect shortly.',
                style: TextStyle(fontSize: 11.5, color: AppColors.onWarningContainer, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _loadMeta,
              child: const Text(
                'Retry',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.onWarningContainer),
              ),
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _isHealthy ? AppColors.successContainer : AppColors.errorContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isHealthy ? AppColors.success.withValues(alpha: 0.3) : AppColors.error.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isHealthy ? Icons.check_circle_rounded : Icons.cloud_off_rounded,
                size: 13,
                color: _isHealthy ? AppColors.onSuccessContainer : AppColors.error,
              ),
              const SizedBox(width: 5),
              Text(
                _isHealthy ? 'AI Service Ready' : 'AI Service Offline',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: _isHealthy ? AppColors.onSuccessContainer : AppColors.onErrorContainer,
                ),
              ),
            ],
          ),
        ),
        if (_backbone != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.memory_rounded, size: 13, color: AppColors.textTertiary),
                const SizedBox(width: 5),
                Text(
                  _backbone!,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        if (count != null)
          GestureDetector(
            onTap: classes.isNotEmpty ? () => _showClassesSheet(classes) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.category_rounded, size: 13, color: AppColors.primary),
                  const SizedBox(width: 5),
                  Text(
                    '$count Categories',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showClassesSheet(List<String> classes) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
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
                'AI Waste Classification Categories',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              const Text(
                'The model is trained to recognize standard domestic waste streams',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ...List.generate(classes.length, (i) {
                final name = classes[i];
                final bin = WasteBin.forCategory(name);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: bin.container,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: bin.color.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Text(bin.emoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: bin.color,
                            borderRadius: BorderRadius.circular(20),
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

  Widget _buildCaptureCard() {
    return AppCard(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      borderColor: AppColors.border,
      borderWidth: 1,
      elevation: 1,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3B82F6), AppColors.primary],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 18),
          const Text(
            'Scan & Classify Waste',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Take a photo of your waste item to instantly identify its category, proper disposal bin, and recycling tips.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: WiseButton(
                    label: 'Take Photo',
                    icon: Icons.photo_camera_rounded,
                    onPressed: () => _pickImage(ImageSource.camera),
                    fullWidth: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: WiseOutlinedButton(
                    label: 'Upload File',
                    icon: Icons.photo_library_rounded,
                    onPressed: () => _pickImage(ImageSource.gallery),
                    fullWidth: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    return AppCard(
      padding: EdgeInsets.zero,
      color: Colors.white,
      borderColor: AppColors.border,
      borderWidth: 1,
      elevation: 2,
      borderRadius: BorderRadius.circular(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
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
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Photo Captured',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                    _previewButton(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Change',
                      onTap: _showPickSheet,
                    ),
                    const SizedBox(width: 8),
                    _previewButton(
                      icon: Icons.refresh_rounded,
                      label: 'Retake',
                      onTap: _reset,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
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

  Widget _buildClassifyButton() {
    final enabled = _imageBytes != null && !_predicting;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: WiseButton(
        label: 'Identify & Classify Waste',
        icon: Icons.auto_awesome_rounded,
        onPressed: enabled ? _classify : null,
        fullWidth: true,
      ),
    );
  }

  Widget _buildProgressCard() {
    return AppCard(
      padding: const EdgeInsets.all(16),
      color: AppColors.primaryContainer,
      borderColor: AppColors.primary.withValues(alpha: 0.25),
      borderWidth: 1,
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      child: const Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Model is analyzing image…',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.onPrimaryContainer),
                ),
                SizedBox(height: 2),
                Text(
                  'Detecting materials and recycling eligibility',
                  style: TextStyle(fontSize: 11.5, color: AppColors.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    final message = _error.toString().replaceFirst('Exception: ', '');
    return AppCard(
      padding: const EdgeInsets.all(16),
      color: AppColors.errorContainer,
      borderColor: AppColors.error.withValues(alpha: 0.25),
      borderWidth: 1,
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
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
                  'Could not classify image',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.onErrorContainer),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.onErrorContainer),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _classify,
                  child: const Text(
                    'Try Again',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.error),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(AiWaste result) {
    final bin = result.bin;
    final bandColor = result.reportedBinColor;
    final categoryData = WasteGuideData.findCategory(result.category);

    return AppCard(
      padding: EdgeInsets.zero,
      color: Colors.white,
      borderColor: AppColors.border,
      borderWidth: 1,
      elevation: 2,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner with category color gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [bandColor, Color.lerp(bandColor, Colors.black, 0.28)!],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: Text(
                      result.icon.isEmpty ? bin.emoji : result.icon,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.category.isEmpty ? bin.name : result.category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Deposit in ${bin.name}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.name.isEmpty ? 'Detected Item' : result.name,
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

                // Confidence Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'AI Confidence',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                    ),
                    Text(
                      '${result.confidencePercent}%',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: bandColor),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: result.confidence.clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: AppColors.surfaceContainer,
                    valueColor: AlwaysStoppedAnimation<Color>(bandColor),
                  ),
                ),
                const SizedBox(height: 14),

                // Tags
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: result.recyclable ? AppColors.successContainer : AppColors.errorContainer,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: result.recyclable
                              ? AppColors.success.withValues(alpha: 0.3)
                              : AppColors.error.withValues(alpha: 0.3),
                        ),
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
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: bin.color.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(bin.icon, size: 13, color: bin.color),
                          const SizedBox(width: 4),
                          Text(
                            bin.name,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: bin.color),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Guidance Box
                if (categoryData != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.tips_and_updates_rounded, size: 14, color: bandColor),
                            const SizedBox(width: 6),
                            const Text(
                              'Disposal Guidance',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          categoryData.properDisposal,
                          style: const TextStyle(
                            fontSize: 11.5,
                            height: 1.45,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                // Actions: Save to Guide & Reset
                ListenableBuilder(
                  listenable: WasteGuideController.instance,
                  builder: (context, _) {
                    final savedCount = WasteGuideController.instance
                        .getSavedCountForCategory(result.category);
                    final alreadySaved = savedCount > 0;
                    return SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: WiseButton(
                        label: alreadySaved ? 'Saved to Waste Guide ($savedCount)' : 'Save to Waste Guide',
                        icon: alreadySaved ? Icons.bookmark_rounded : Icons.bookmark_add_rounded,
                        onPressed: () async {
                          final bytes = _imageBytes;
                          final name = _imageName;
                          if (bytes == null || name == null) return;
                          final mainScope = MainScreenScope.of(context);
                          await WasteGuideController.instance
                              .saveAiResult(result, imageBytes: bytes, imageName: name);
                          if (!mounted) return;
                          _snack('Saved ${result.category} guide!');
                          WasteGuideController.instance
                              .setSelectedCategory(result.category);
                          mainScope?.selectTab(2);
                        },
                        backgroundColor: alreadySaved
                            ? AppColors.successContainer
                            : AppColors.primary,
                        foregroundColor: alreadySaved
                            ? AppColors.onSuccessContainer
                            : Colors.white,
                        fullWidth: true,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: WiseTextButton(
                    label: 'Scan Another Waste Item',
                    onPressed: _reset,
                    color: AppColors.textSecondary,
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
