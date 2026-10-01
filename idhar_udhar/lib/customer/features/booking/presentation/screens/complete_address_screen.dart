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
  const CompleteAddressScreen({
    required this.initial,
    this.forPickup = false,
    super.key,
  });

  final MockLocation initial;

  /// Pickup and drop keep separate forms. Drop never reads pickup fields.
  final bool forPickup;

  static Future<MockLocation?> open(
    BuildContext context, {
    required MockLocation initial,
    bool forPickup = false,
  }) {
    return Navigator.of(context).push<MockLocation>(
      MaterialPageRoute<MockLocation>(
        builder: (_) => CompleteAddressScreen(
          initial: initial,
          forPickup: forPickup,
        ),
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
  final FocusNode _streetFocus = FocusNode();
  final FocusNode _addressFocus = FocusNode();
  final GlobalKey _houseKey = GlobalKey();
  final GlobalKey _societyKey = GlobalKey();
  final GlobalKey _streetKey = GlobalKey();
  final GlobalKey _addressKey = GlobalKey();
  late final TextEditingController _house;
  late final TextEditingController _society;
  late final TextEditingController _street;
  late final TextEditingController _address;

  @override
  void initState() {
    super.initState();
    final BookingDraft draft = ref.read(bookingDraftProvider);
    final MockLocation initial = widget.initial;
    final bool editingPickup = widget.forPickup && identical(draft.pickup, initial);
    _house = TextEditingController(
      text: initial.unit.trim().isNotEmpty
          ? initial.unit
          : (editingPickup ? draft.pickupHouse : ''),
    );
    _society = TextEditingController(
      text: initial.premises.trim().isNotEmpty
          ? initial.premises
          : (editingPickup ? draft.pickupSociety : ''),
    );
    _street = TextEditingController(text: initial.landmark.trim());
    _address = TextEditingController(
      text: initial.address.trim().isNotEmpty
          ? initial.address
          : initial.label,
    );
    _houseFocus.addListener(() => _reveal(_houseFocus, _houseKey));
    _societyFocus.addListener(() => _reveal(_societyFocus, _societyKey));
    _streetFocus.addListener(() => _reveal(_streetFocus, _streetKey));
    _addressFocus.addListener(() => _reveal(_addressFocus, _addressKey));
  }

  @override
  void dispose() {
    _scroll.dispose();
    _houseFocus.dispose();
    _societyFocus.dispose();
    _streetFocus.dispose();
    _addressFocus.dispose();
    _house.dispose();
    _society.dispose();
    _street.dispose();
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

  void _confirm() {
    final String address = _address.text.trim();
    if (!_hasPin || address.isEmpty) {
      return;
    }
    final String house = _house.text.trim();
    final String society = _society.text.trim();
    final String street = _street.text.trim();
    Navigator.of(context).pop(
      widget.initial.copyWith(
        address: address,
        unit: house,
        premises: society,
        landmark: street,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canConfirm = _hasPin && _address.text.trim().isNotEmpty;
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return GlassPageScaffold(
      bottom: AnimatedPrimaryButton(
        label: 'Confirm Address',
        enabled: canConfirm,
        onPressed: canConfirm ? _confirm : null,
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
            'Add any house or building details, then confirm this pickup or drop.',
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
          const SizedBox(height: AppSpacing.lg),
          KeyedSubtree(
            key: _houseKey,
            child: GlassTextField(
              controller: _house,
              focusNode: _houseFocus,
              label: 'House No / Floor No / Block No / Office No',
              hint: '101, Floor 3, Block B, Office 402',
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
              label: 'Building Name / Society Name / Office Name',
              hint: 'Shreyansh Tower, Shree Residency',
              leadingIcon: Icons.apartment_outlined,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _streetFocus.requestFocus(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          KeyedSubtree(
            key: _streetKey,
            child: GlassTextField(
              controller: _street,
              focusNode: _streetFocus,
              label: 'Street Name / Near Location',
              hint: 'Satellite Road',
              leadingIcon: Icons.signpost_outlined,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _addressFocus.requestFocus(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          KeyedSubtree(
            key: _addressKey,
            child: GlassTextField(
              controller: _address,
              focusNode: _addressFocus,
              label: 'Complete Address',
              hint: 'Satellite, Ahmedabad, Gujarat',
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
