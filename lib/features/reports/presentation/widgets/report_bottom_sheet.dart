import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/modal_drag_handle.dart';
import '../../../../core/widgets/seriolab_loader.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/report_model.dart';
import '../providers/report_providers.dart';

/// Opens the standardized Report Bottom Sheet.
Future<bool?> showReportBottomSheet({
  required BuildContext context,
  required ReportTargetType targetType,
  required String targetId,
  required String reportedUserId,
  String? reportedUsername,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: const Color(0xFF0D0F17),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => ReportBottomSheet(
      targetType: targetType,
      targetId: targetId,
      reportedUserId: reportedUserId,
      reportedUsername: reportedUsername,
    ),
  );
}

/// Standardized bottom sheet modal for reporting offensive comments or user profiles.
class ReportBottomSheet extends ConsumerStatefulWidget {
  const ReportBottomSheet({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.reportedUserId,
    this.reportedUsername,
  });

  final ReportTargetType targetType;
  final String targetId;
  final String reportedUserId;
  final String? reportedUsername;

  @override
  ConsumerState<ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends ConsumerState<ReportBottomSheet> {
  late String _selectedReason;
  final TextEditingController _detailsController = TextEditingController();
  bool _isSubmitting = false;

  static const List<String> _commentReasons = [
    'Hate speech or harassment',
    'Spam or advertisement',
    'Unmarked spoilers',
    'Other reason',
  ];

  static const List<String> _profileReasons = [
    'Hate speech or harassment',
    'Inappropriate photo, avatar, or banner',
    'Inappropriate nickname or bio',
    'Spam or advertisement',
    'Other reason',
  ];

  List<String> get _reasons =>
      widget.targetType == ReportTargetType.comment
          ? _commentReasons
          : _profileReasons;

  @override
  void initState() {
    super.initState();
    _selectedReason = _reasons.first;
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      String reporterUserId = 'anonymous';
      try {
        final authUser = ref.read(authControllerProvider).user;
        if (authUser != null && authUser.uid.isNotEmpty) {
          reporterUserId = authUser.uid;
        } else if (Firebase.apps.isNotEmpty) {
          reporterUserId =
              FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
        }
      } catch (_) {}

      final report = ReportModel(
        id: 'rep_${DateTime.now().millisecondsSinceEpoch}',
        reporterUserId: reporterUserId,
        targetType: widget.targetType,
        targetId: widget.targetId,
        reportedUserId: widget.reportedUserId,
        reason: _selectedReason,
        details: _detailsController.text.trim(),
        createdAt: DateTime.now(),
        status: ReportStatus.pending,
      );

      await ref.read(reportRepositoryProvider).submitReport(report);

      if (!mounted) return;
      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Report submitted successfully. Thank you for keeping our community safe.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.surfaceHigh,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (err) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting report: $err'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isComment = widget.targetType == ReportTargetType.comment;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Single grey drag handle
              const ModalDragHandle(
                color: Color(0xFF4B5563),
                topPadding: 12,
                bottomPadding: 16,
              ),

              // Title
              Text(
                isComment ? 'Report Comment' : 'Report Profile',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),

              // Subtitle
              const Text(
                'Help us keep the Seriolab community safe.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),

              // Reason selection list
              ..._reasons.map(_buildReasonTile),

              const SizedBox(height: 12),

              // Optional details text field
              TextField(
                controller: _detailsController,
                maxLines: 3,
                maxLength: 300,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Additional details (optional)...',
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                  counterStyle: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1E2333),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF232938)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF232938)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SeriolabLoader(size: 24)
                      : const Text(
                          'Submit Report',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 8),

              // Cancel button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReasonTile(String reason) {
    final isSelected = _selectedReason == reason;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedReason = reason;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.15)
                : const Color(0xFF1E2333),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : const Color(0xFF232938),
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.textMuted,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  reason,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
