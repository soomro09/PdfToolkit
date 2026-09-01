import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf_utility_app/views/recent_files.dart';
import 'package:pdf_utility_app/views/settings_screen.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../models/pdf_tool_type.dart';
import '../../../../views/widgets/recent_file_tile.dart';
import '../../../pdf/controllers/recent_file_controller.dart';
import '../../controllers/home_controller.dart';
import '../../widgets/tool_category_section.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _headerSlide;
  late final Animation<Offset> _listSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _headerSlide =
        Tween<Offset>(begin: const Offset(0, -0.15), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
          ),
        );
    _listSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.forward());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showRecentFileOptions(BuildContext context, dynamic file) {
    HapticFeedback.lightImpact();
    final primaryColor = Theme.of(context).primaryColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.picture_as_pdf_rounded,
                      color: primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name ?? 'Document.pdf',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          file.path ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(
                  Icons.share_outlined,
                  color: AppColors.textPrimary,
                ),
                title: const Text(
                  'Share',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                onTap: () async {
                  Navigator.pop(modalContext);
                  if (file.path != null && await File(file.path).exists()) {
                    await Share.shareXFiles([XFile(file.path)]);
                  }
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.open_in_new_rounded,
                  color: AppColors.textPrimary,
                ),
                title: const Text(
                  'Open',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                onTap: () {
                  Navigator.pop(modalContext);
                  HomeScreenController.openRecentFile(context, ref, file);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Remove from Recent',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.error,
                  ),
                ),
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                onTap: () {
                  Navigator.pop(modalContext);
                  ref
                      .read(recentFilesProvider.notifier)
                      .removeFile(file.id ?? file.path);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dynamicRecentFiles = ref.watch(recentFilesProvider);
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: primaryColor,
              surfaceTintColor: Colors.transparent,
              pinned: true,
              floating: true,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              title: SlideTransition(
                position: _headerSlide,
                child: const Text(
                  'PDF Pro',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    fontSize: 20,
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.settings_outlined,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
            const ToolCategorySection(
              title: 'Organize & Edit',
              icon: Icons.edit_document,
              tools: [
                PdfToolType.editPdf,
                PdfToolType.merge,
                PdfToolType.split,
                PdfToolType.organizePdf,
              ],
            ),
            const ToolCategorySection(
              title: 'Convert & Scan',
              icon: Icons.document_scanner_rounded,
              tools: [
                PdfToolType.compress,
                PdfToolType.scanner,
                PdfToolType.textToPdf,
                PdfToolType.pdfToText,
                PdfToolType.pdfToJpg,
                PdfToolType.imagesToPdf,
              ],
            ),
            const ToolCategorySection(
              title: 'Security & Sign',
              icon: Icons.security_rounded,
              tools: [
                PdfToolType.sign,
                PdfToolType.watermark,
                PdfToolType.protect,
                PdfToolType.unlockPdf,
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
              sliver: SliverToBoxAdapter(
                child: SlideTransition(
                  position: _listSlide,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Files',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (dynamicRecentFiles.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const AllRecentFilesScreen(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: primaryColor,
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'View All',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: dynamicRecentFiles.isEmpty
                  ? const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(28.0),
                          child: Text(
                            "No recent files yet. Process a PDF to see it here!",
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final file = dynamicRecentFiles[index];
                        return SlideTransition(
                          position: _listSlide,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: RecentFileTile(
                              file: file,
                              onTap: () => HomeScreenController.openRecentFile(
                                context,
                                ref,
                                file,
                              ),
                              onMoreTap: () =>
                                  _showRecentFileOptions(context, file),
                            ),
                          ),
                        );
                      }, childCount: dynamicRecentFiles.length),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
