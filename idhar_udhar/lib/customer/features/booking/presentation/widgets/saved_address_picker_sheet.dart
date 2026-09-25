import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/mock/mock_models.dart';
import '../../../../core/state/saved_addresses_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/glass_container.dart';

Future<MockLocation?> showSavedAddressPicker(BuildContext context) {
  return showModalBottomSheet<MockLocation>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => const SavedAddressPickerSheet(),
  );
}

class SavedAddressPickerSheet extends ConsumerWidget {
  const SavedAddressPickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SavedAddressesState state = ref.watch(savedAddressesProvider);
    final double height = MediaQuery.sizeOf(context).height * 0.62;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: GlassContainer(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SizedBox(
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Saved Address', style: AppTextStyles.headingS),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : state.addresses.isEmpty
                        ? const EmptyState(
                            title: 'No saved addresses',
                            subtitle:
                                'Add Home, Office, Friend or Other for faster booking.',
                          )
                        : ListView.separated(
                            itemCount: state.addresses.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (BuildContext context, int index) {
                              final MockLocation loc = state.addresses[index];
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: AppRadius.lgAll,
                                  onTap: () => Navigator.of(context).pop(loc),
                                  child: GlassContainer(
                                    padding: const EdgeInsets.all(AppSpacing.lg),
                                    borderRadius: AppRadius.lgAll,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          loc.displayLabel,
                                          style: AppTextStyles.bodyMedium,
                                        ),
                                        Text(
                                          loc.address,
                                          style: AppTextStyles.caption.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
