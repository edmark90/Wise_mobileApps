import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../controllers/waste_guide_controller.dart';
import '../models/ai_waste.dart';
import '../models/waste_bin.dart';
import '../models/waste_guide.dart';
import '../widgets/common/speech_section.dart';

/// Detail screen for a saved AI waste classification result.
class SavedWasteDetailScreen extends StatefulWidget {
  final SavedAiWaste savedResult;

  const SavedWasteDetailScreen({super.key, required this.savedResult});

  @override
  State<SavedWasteDetailScreen> createState() =>
      _SavedWasteDetailScreenState();
}

class _SavedWasteDetailScreenState extends State<SavedWasteDetailScreen> {
  final WasteGuideController _controller = WasteGuideController.instance;

  void _snack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFC62828) : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _removeSaved() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Saved Guide'),
        content: Text(
            'Remove "${widget.savedResult.category}" from your saved guides?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _controller.removeAiResultById(widget.savedResult.id);
      if (!mounted) return;
      _snack('Removed ${widget.savedResult.category} guide');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.savedResult;
    final bin = result.bin;
    final bandColor = result.reportedBinColor;
    final category = WasteGuideData.findCategory(result.category);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Hero image ──────────────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            stretch: true,
            backgroundColor: bandColor,
            leading: _buildCircleButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.pop(context),
            ),
            actions: [
              _buildCircleButton(
                icon: Icons.delete_outline_rounded,
                onTap: _removeSaved,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(result.imageBytes, fit: BoxFit.cover),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          bandColor.withValues(alpha: 0.85),
                        ],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),
                  // Bottom info overlay
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Confidence pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_rounded,
                                  size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                'AI Confidence: ${result.confidencePercent}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Category + bin
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  result.icon.isEmpty
                                      ? bin.emoji
                                      : result.icon,
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    result.category,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Dispose in ${bin.name}',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white
                                            .withValues(alpha: 0.9)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Content ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + tagalog
                  Text(
                    result.name.isEmpty ? 'Recognized Waste' : result.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (result.tagalogName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      result.tagalogName,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Saved ${_formatDate(result.savedAt)}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 16),

                  // Confidence card
                  _buildConfidenceCard(result, bandColor),
                  const SizedBox(height: 14),

                  // Tags
                  _buildTags(result, bin),
                  const SizedBox(height: 20),

                  // Guide section
                  if (category != null)
                    _buildGuideSection(category)
                  else
                    _buildBasicInfo(bin),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Circle back / delete button ────────────────────────────────

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onTap,
      ),
    );
  }

  // ── Confidence card ───────────────────────────────────────────

  Widget _buildConfidenceCard(SavedAiWaste result, Color bandColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadowMedium,
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: bandColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.insights_rounded,
                    size: 14, color: bandColor),
              ),
              const SizedBox(width: 8),
              const Text(
                'AI Confidence',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              const Spacer(),
              Text(
                '${result.confidencePercent}%',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: bandColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: result.confidence.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.surfaceContainer,
              valueColor: AlwaysStoppedAnimation<Color>(bandColor),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tags ──────────────────────────────────────────────────────

  Widget _buildTags(SavedAiWaste result, WasteBin bin) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildChip(
          icon: result.recyclable
              ? Icons.recycling_rounded
              : Icons.block_rounded,
          label: result.recyclable ? 'Recyclable' : 'Non-Recyclable',
          color: result.recyclable
              ? AppColors.successContainer
              : AppColors.errorContainer,
          iconColor: result.recyclable
              ? AppColors.onSuccessContainer
              : AppColors.onErrorContainer,
          textColor: result.recyclable
              ? AppColors.onSuccessContainer
              : AppColors.onErrorContainer,
        ),
        _buildChip(
          icon: bin.icon,
          label: 'Deposit in ${bin.name}',
          color: bin.container,
          iconColor: bin.color,
          textColor: bin.color,
        ),
        _buildChip(
          icon: Icons.schedule_rounded,
          label: _formatTimeAgo(result.savedAt),
          color: AppColors.surfaceContainer,
          iconColor: AppColors.textSecondary,
          textColor: AppColors.textSecondary,
        ),
      ],
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String label,
    required Color color,
    required Color iconColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: textColor)),
        ],
      ),
    );
  }

  // ── Guide section ─────────────────────────────────────────────

  Widget _buildGuideSection(WasteGuideCategory category) {
    return SpeechReader(
      sections: [
        SpeechText(
          title: 'Description',
          text: category.description,
          icon: Icons.description_rounded,
          color: category.color,
        ),
        SpeechText(
          title: 'Proper Disposal',
          text: category.properDisposal,
          icon: Icons.check_circle_rounded,
          color: category.color,
        ),
        SpeechText(
          title: "Don't Do",
          text: category.dontDo,
          icon: Icons.cancel_rounded,
          color: AppColors.error,
        ),
      ],
    );
  }

  // ── Basic info (no category match) ────────────────────────────

  Widget _buildBasicInfo(WasteBin bin) {
    return _buildSectionCard(
      title: 'Disposal Information',
      icon: bin.icon,
      color: bin.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Please dispose this waste in the ${bin.name.toLowerCase()}.',
            style: const TextStyle(
                fontSize: 13, height: 1.4, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          Text(
            bin.name,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: bin.color),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadowMedium,
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
