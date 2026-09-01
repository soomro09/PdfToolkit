import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../models/pdf_document_model.dart';
import '../feature/pdf/controllers/recent_file_controller.dart';
import '../feature/pdf/views/pdf_result_screen.dart';
import 'widgets/custom_app_bar.dart';
import 'widgets/recent_file_tile.dart';

class AllRecentFilesScreen extends ConsumerStatefulWidget {
  const AllRecentFilesScreen({super.key});

  @override
  ConsumerState<AllRecentFilesScreen> createState() =>
      _AllRecentFilesScreenState();
}

class _AllRecentFilesScreenState extends ConsumerState<AllRecentFilesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openFile(PdfDocumentModel fileModel) {
    final file = File(fileModel.path);
    if (!file.existsSync()) {
      ref.read(recentFilesProvider.notifier).removeFile(fileModel.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File no longer exists on device storage.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PdfResultScreen(resultFiles: [file], title: fileModel.name),
      ),
    );
  }

  void _showFileOptions(PdfDocumentModel fileModel) {
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
                          fileModel.name,
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
                          fileModel.path,
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
                  if (await File(fileModel.path).exists()) {
                    await Share.shareXFiles([XFile(fileModel.path)]);
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
                  _openFile(fileModel);
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
                      .removeFile(fileModel.id);
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
    final recentFiles = ref.watch(recentFilesProvider);

    final filteredFiles = recentFiles.where((file) {
      return file.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(
        title: 'All Recent Files',
        showBackButton: true,
      ),
      body: Column(
        children: [
          if (recentFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search your PDFs...',
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary.withOpacity(0.7),
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppColors.primaryRed,
                    size: 22,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.cancel_rounded,
                            color: AppColors.textMuted,
                            size: 20,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: AppColors.primaryRed,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: recentFiles.isEmpty
                ? _buildEmptyState(
                    icon: Icons.folder_open_rounded,
                    message: 'No recent files found',
                  )
                : filteredFiles.isEmpty
                ? _buildEmptyState(
                    icon: Icons.search_off_rounded,
                    message: 'No files match "$_searchQuery"',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredFiles.length,
                    itemBuilder: (context, index) {
                      final fileModel = filteredFiles[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: RecentFileTile(
                          file: fileModel,
                          onTap: () => _openFile(fileModel),
                          onMoreTap: () => _showFileOptions(fileModel),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.textMuted.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
