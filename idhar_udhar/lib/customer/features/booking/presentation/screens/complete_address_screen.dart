import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/mock/mock_models.dart';
import '../../../../core/state/booking_draft_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/widgets/glass_page_scaffold.dart';
import '../../../../shared/widgets/iu_back_button.dart';

/// Reviews the map or saved pin and lets the customer complete the address
/// without dropping the selected coordinates.
class CompleteAddressScreen extends ConsumerStatefulWidget {
  const CompleteAddressScreen({required this.initial, super.key});

  final MockLocation initial;

  static Future<MockLocation?> open(
    BuildContext context, {
    required MockLocation initial,
  }) {
    return Navigator.of(context).push<MockLocation>(
      MaterialPageRoute<MockLocation>(
        builder: (_) => CompleteAddressScreen(initial: initial),
      ),
    );
  }

  @override
  ConsumerState<CompleteAddressScreen> createState() =>
      _CompleteAddressScreenState();
}

class _CompleteAddressScreenState extends ConsumerState<CompleteAddressScreen> {
  final ScrollController _scroll = ScrollController();
  final FocusNode _houseFocus = FocusNode();
  final FocusNode _societyFocus = FocusNode();
  final FocusNode _addressFocus = FocusNode();
  final GlobalKey _houseKey = GlobalKey();
  final GlobalKey _societyKey = GlobalKey();
  final GlobalKey _addressKey = GlobalKey();
  late final TextEditingController _house;
  late final TextEditingController _society;
  late final TextEditingController _address;

  @override
  void initState() {
    super.initState();
    final BookingDraft draft = ref.read(bookingDraftProvider);
    final MockLocation initial = widget.initial;
    final bool samePickup = draft.pickup?.id == initial.id;
    _house = TextEditingController(
      text: initial.unit.trim().isNotEmpty
          ? initial.unit
          : (samePickup ? draft.pickupHouse : ''),
    );
    _society = TextEditingController(
      text: initial.premises.trim().isNotEmpty
          ? initial.premises
          : initial.landmark.trim().isNotEmpty
              ? initial.landmark
              : (samePickup ? draft.pickupSociety : ''),
    );
    _address = TextEditingController(
      text: initial.address.trim().isNotEmpty
          ? initial.address
          : initial.label,
    );
    _houseFocus.addListener(() => _reveal(_houseFocus, _houseKey));
    _societyFocus.addListener(() => _reveal(_societyFocus, _societyKey));
    _addressFocus.addListener(() => _reveal(_addressFocus, _addressKey));
  }

  @override
  void dispose() {
    _scroll.dispose();
    _houseFocus.dispose();
    _societyFocus.dispose();
    _addressFocus.dispose();
    _house.dispose();
    _society.dispose();
    _address.dispose();
    super.dispose();
  }

  void _reveal(FocusNode node, GlobalKey key) {
    if (!node.hasFocus) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? target = key.currentContext;
      if (target == null || !target.mounted) {
        return;
      }
      Scrollable.ensureVisible(
        target,
        alignment: 0.15,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  bool get _hasPin =>
      widget.initial.latitude != null && widget.initial.longitude != null;

  void _confirm(bool residential) {
    final String address = _address.text.trim();
    if (!_hasPin || address.isEmpty) {
      return;
    }
    final String house = residential ? _house.text.trim() : '';
    final String society = residential ? _society.text.trim() : '';
    Navigator.of(context).pop(
      widget.initial.copyWith(
        address: address,
        unit: house,
        premises: society,
        landmark: society.isNotEmpty ? society : widget.initial.landmark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final BookingDraft draft = ref.watch(bookingDraftProvider);
    final bool residential = draft.usesResidentialPickup;
    final bool canConfirm = _hasPin && _address.text.trim().isNotEmpty;
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return GlassPageScaffold(
      bottom: AnimatedPrimaryButton(
        label: 'Confirm Address',
        enabled: canConfirm,
        onPressed: canConfirm ? () => _confirm(residential) : null,
      ),
      child: ListView(
        controller: _scroll,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Row(
            children: [
              IuBackButton(onPressed: () => Navigator.of(context).pop()),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Complete Your Address',
                  style: AppTextStyles.headingS,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            residential
                ? 'Add the house details, then confirm this pickup or drop.'
                : 'Review the address, then confirm this pickup or drop.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (!_hasPin) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'This place has no map pin. Choose it on the map before confirming.',
              style: AppTextStyles.caption.copyWith(color: AppColors.orange),
            ),
          ],
          if (residential) ...[
            const SizedBox(height: AppSpacing.lg),
            KeyedSubtree(
              key: _houseKey,
              child: GlassTextField(
                controller: _house,
                focusNode: _houseFocus,
                hint: 'House / Flat No.',
                leadingIcon: Icons.home_outlined,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _societyFocus.requestFocus(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            KeyedSubtree(
              key: _societyKey,
              child: GlassTextField(
                controller: _society,
                focusNode: _societyFocus,
                hint: 'Flat / Society',
                leadingIcon: Icons.apartment_outlined,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _addressFocus.requestFocus(),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          KeyedSubtree(
            key: _addressKey,
            child: GlassTextField(
              controller: _address,
              focusNode: _addressFocus,
              hint: 'Full Address',
              leadingIcon: Icons.place_outlined,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
            ),
          ),
          SizedBox(height: keyboard > 0 ? keyboard : AppSpacing.xl),
        ],
      ),
    );
  }
}
