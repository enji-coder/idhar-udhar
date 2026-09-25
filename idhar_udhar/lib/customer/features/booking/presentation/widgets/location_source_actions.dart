import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';

class LocationSourceActions extends StatelessWidget {
  const LocationSourceActions({
    required this.onMap,
    required this.onSaved,
    super.key,
  });

  final VoidCallback onMap;
  final VoidCallback onSaved;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextButton.icon(
            onPressed: onMap,
            icon: const Icon(Icons.map_outlined, color: AppColors.orange),
            label: Text(
              'Select on Map',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Container(
          width: 1,
          height: 18,
          color: AppColors.navy.withValues(alpha: 0.2),
        ),
        Expanded(
          child: TextButton.icon(
            onPressed: onSaved,
            icon: const Icon(Icons.bookmark_outline_rounded, color: AppColors.orange),
            label: Text(
              'Saved Address',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
