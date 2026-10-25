import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../controllers/waste_guide_controller.dart';
import '../models/ai_waste.dart';
import '../models/waste_guide.dart';
import 'saved_waste_detail_screen.dart';

/// Waste Guide page — search bar + saved AI-scan results.
class WasteGuideScreen extends StatefulWidget {
  const WasteGuideScreen({super.key});

  @override
  State<WasteGuideScreen> createState() => _WasteGuideScreenState();
}

class _WasteGuideScreenState extends State<WasteGuideScreen> {
  final WasteGuideController _controller = WasteGuideController.instance;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _controller.load();
    _controller.addListener(_onControllerChange);
    if (_controller.selectedCategory != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToSavedSection();
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChange);
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onControllerChange() {
    if (_controller.selectedCategory != null && mounted) {
      _scrollToSavedSection();
    }
  }

  final GlobalKey _savedSectionKey = GlobalKey();

  void _scrollToSavedSection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _savedSectionKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
      }
    });
  }

  List<SavedAiWaste> get _filteredSaved {
    final results = _controller.savedAiResults;
    if (_searchQuery.isEmpty) return results;
    final q = _searchQuery.toLowerCase();
    return results.where((r) {
      return r.name.toLowerCase().contains(q) ||
          r.category.toLowerCase().contains(q) ||
          r.bin.name.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: GestureDetector(
        onTap: () => _searchFocus.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildSearchHero()),
                SliverToBoxAdapter(
                  key: _savedSectionKey,
                  child: _buildSavedSectionHeader(),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                ..._buildSavedSlivers(),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Search hero ───────────────────────────────────────────────────

  Widget _buildSearchHero() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Waste Guide',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (_controller.savedAiResults.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bookmark_rounded,
                          size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        '${_controller.savedAiResults.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search waste types, categories...',
                hintStyle: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textTertiary,
                ),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 20, color: AppColors.textTertiary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 18, color: AppColors.textTertiary),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Saved section ─────────────────────────────────────────────────

  Widget _buildSavedSectionHeader() {
    final saved = _controller.savedAiResults;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.bookmark_rounded,
                size: 17, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Saved Scans',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  saved.isEmpty
                      ? 'No saved scans yet'
                      : '${saved.length} scan${saved.length == 1 ? '' : 's'} from AI',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (saved.isNotEmpty)
            const Icon(Icons.auto_awesome_rounded,
                size: 14, color: AppColors.primary),
        ],
      ),
    );
  }

  List<Widget> _buildSavedSlivers() {
    if (!_controller.isLoaded) {
      return [
        const SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
        ),
      ];
    }

    final saved = _filteredSaved;

    if (_controller.savedAiResults.isEmpty) {
      return [SliverToBoxAdapter(child: _buildSavedEmpty())];
    }

    if (saved.isEmpty && _searchQuery.isNotEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.search_off_rounded,
                      size: 36, color: AppColors.textTertiary),
                  const SizedBox(height: 8),
                  Text(
                    'No saved scans match "$_searchQuery"',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.separated(
          itemCount: saved.length,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (context, index) => _buildSavedResultCard(saved[index]),
        ),
      ),
    ];
  }

  Widget _buildSavedResultCard(SavedAiWaste savedResult) {
    final category = WasteGuideData.findCategory(savedResult.category);
    final bin = savedResult.bin;
    final bandColor = savedResult.reportedBinColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  SavedWasteDetailScreen(savedResult: savedResult)),
        ),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowMedium,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: image + info + actions ──────────
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                        ),
                        child: Image.memory(
                          savedResult.imageBytes,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category name
                          Text(
                            savedResult.name.isEmpty
                                ? savedResult.category
                                : savedResult.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // Bin name
                          Row(
                            children: [
                              Icon(Icons.restore_from_trash_rounded,
                                  size: 14, color: bin.color),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  bin.name,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: bin.color,
                                      fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Category tag (only if different from name)
                          if (savedResult.category.isNotEmpty &&
                              savedResult.category != savedResult.name)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: bandColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                savedResult.category,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: bandColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Right side: confidence + actions
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Confidence badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: bandColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${savedResult.confidencePercent}%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: bandColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Delete button
                        GestureDetector(
                          onTap: () => _confirmDelete(savedResult),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.delete_outline_rounded,
                                size: 14, color: Color(0xFFDC2626)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Tags row ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (savedResult.recyclable)
                      _buildMiniChip(
                        icon: Icons.recycling_rounded,
                        label: 'Recyclable',
                        color: AppColors.successContainer,
                        textColor: AppColors.onSuccessContainer,
                      ),
                    _buildMiniChip(
                      icon: Icons.restore_from_trash_rounded,
                      label: bin.name,
                      color: bin.container,
                      textColor: bin.color,
                    ),
                    _buildMiniChip(
                      icon: Icons.schedule_rounded,
                      label: _formatTimeAgo(savedResult.savedAt),
                      color: AppColors.surfaceContainer,
                      textColor: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),

              // ── Guide preview ─────────────────────────────
              if (category != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppColors.border, width: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: category.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(Icons.description_rounded,
                                size: 12, color: category.color),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Disposal Guide',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        category.properDisposal,
                        style: const TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: AppColors.textPrimary),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniChip({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: textColor)),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(SavedAiWaste savedResult) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Saved Guide'),
        content:
            Text('Remove "${savedResult.category}" from your saved guides?'),
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
    if (confirmed == true) {
      await _controller.removeAiResultById(savedResult.id);
    }
  }

  Widget _buildSavedEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  size: 34, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 14),
            const Text(
              'No Saved Scans Yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Use the AI Waste Scanner to photograph waste and save the classification result.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
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
