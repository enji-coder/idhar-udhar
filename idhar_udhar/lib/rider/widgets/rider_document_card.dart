import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/models/rider_document.dart';
import '../theme/rider_colors.dart';
import '../theme/rider_spacing.dart';
import '../theme/rider_text_styles.dart';
import 'rider_glass_card.dart';
import 'rider_section_header.dart';

class RiderDocumentCard extends StatelessWidget {
  const RiderDocumentCard({
    required this.document,
    required this.onUpload,
    super.key,
    this.onReplace,
    this.onView,
  });

  final RiderDocument document;
  final VoidCallback onUpload;
  final VoidCallback? onReplace;
  final VoidCallback? onView;

  RiderChipTone get _tone {
    switch (document.status) {
      case RiderDocumentStatus.verified:
        return RiderChipTone.success;
      case RiderDocumentStatus.pendingVerification:
      case RiderDocumentStatus.uploaded:
        return RiderChipTone.warning;
      case RiderDocumentStatus.uploadRequired:
        return RiderChipTone.error;
    }
  }

  IconData get _icon {
    switch (document.kind) {
      case RiderDocumentKind.aadhaarFront:
      case RiderDocumentKind.aadhaarBack:
        return Icons.badge_outlined;
      case RiderDocumentKind.panFront:
        return Icons.credit_card_rounded;
      case RiderDocumentKind.drivingLicenseFront:
      case RiderDocumentKind.drivingLicenseBack:
        return Icons.directions_car_filled_outlined;
      case RiderDocumentKind.vehicleRcFront:
      case RiderDocumentKind.vehicleRcBack:
        return Icons.description_outlined;
      case RiderDocumentKind.bankProof:
        return Icons.account_balance_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool needsUpload =
        document.status == RiderDocumentStatus.uploadRequired;
    final bool showImagePreview = !kIsWeb &&
        document.localPath != null &&
        document.isImage &&
        File(document.localPath!).existsSync();

    return RiderGlassCard(
      padding: const EdgeInsets.all(RiderSpacing.lg),
      borderRadius: RiderRadius.lgAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: RiderColors.primary.withValues(alpha: 0.12),
                  borderRadius: RiderRadius.mdAll,
                ),
                clipBehavior: Clip.antiAlias,
                child: showImagePreview
                    ? Image.file(
                        File(document.localPath!),
                        fit: BoxFit.cover,
                      )
                    : Icon(_icon, color: RiderColors.primary),
              ),
              const SizedBox(width: RiderSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(document.kind.label, style: RiderTextStyles.bodyMedium),
                    const SizedBox(height: 2),
                    Text(
                      document.kind.description,
                      style: RiderTextStyles.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: RiderSpacing.md),
          Row(
            children: [
              RiderStatusChip(
                label: document.status.label,
                tone: _tone,
                icon: document.status == RiderDocumentStatus.verified
                    ? Icons.verified_rounded
                    : Icons.info_outline_rounded,
              ),
              const SizedBox(width: RiderSpacing.sm),
              const RiderStatusChip(
                label: 'Required',
                tone: RiderChipTone.warning,
              ),
            ],
          ),
          if (document.fileName != null) ...[
            const SizedBox(height: RiderSpacing.sm),
            Text(
              document.fileName!,
              style: RiderTextStyles.caption.copyWith(
                color: RiderColors.textPrimary,
              ),
            ),
          ],
          const SizedBox(height: RiderSpacing.md),
          Wrap(
            spacing: RiderSpacing.sm,
            runSpacing: RiderSpacing.sm,
            children: [
              if (needsUpload)
                _ActionChip(
                  label: 'Upload',
                  icon: Icons.upload_rounded,
                  onTap: onUpload,
                )
              else ...[
                if (onView != null)
                  _ActionChip(
                    label: 'View',
                    icon: Icons.visibility_outlined,
                    onTap: onView!,
                  ),
                if (onReplace != null)
                  _ActionChip(
                    label: 'Replace',
                    icon: Icons.sync_rounded,
                    onTap: onReplace!,
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RiderColors.surface,
      borderRadius: RiderRadius.pillAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: RiderRadius.pillAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: RiderSpacing.md,
            vertical: RiderSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: RiderColors.primary),
              const SizedBox(width: RiderSpacing.xs),
              Text(
                label,
                style: RiderTextStyles.caption.copyWith(
                  color: RiderColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
