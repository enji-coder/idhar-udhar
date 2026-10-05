import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/vehicle_category/vehicle_category.dart';
import 'package:idhar_udhar/shared/vehicle_category/vehicle_category_catalog.dart';

import '../../data/dummy/dummy_rider_repository.dart';
import '../../data/local/rider_permissions.dart';
import '../../data/models/vehicle_info.dart';
import '../../routing/rider_routes.dart';
import '../../state/rider_session.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_glass_card.dart';
import '../../widgets/rider_primary_button.dart';
import '../../widgets/rider_scaffold.dart';
import '../../widgets/rider_text_field.dart';

class VehicleDetailsScreen extends ConsumerStatefulWidget {
  const VehicleDetailsScreen({
    super.key,
    this.vehicleType,
    this.categoryName,
    this.editMode = false,
  });

  final RiderVehicleType? vehicleType;
  final String? categoryName;
  final bool editMode;

  @override
  ConsumerState<VehicleDetailsScreen> createState() =>
      _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends ConsumerState<VehicleDetailsScreen> {
  late final TextEditingController _number;
  late final TextEditingController _model;
  late final TextEditingController _color;
  late final TextEditingController _year;
  late RiderVehicleType _type;
  late String _categoryName;
  String? _numberError;
  String? _modelError;
  String? _colorError;
  String? _yearError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final VehicleInfo stored = ref.read(riderVehicleProvider);
    final bool useStored = stored.hasDetails;
    _type = widget.vehicleType ??
        (widget.categoryName != null
            ? RiderVehicleTypeX.fromLabel(widget.categoryName)
            : (useStored ? stored.type : RiderVehicleType.bike));
    _categoryName = widget.categoryName ??
        (useStored ? (stored.categoryName ?? '') : '');
    _number = TextEditingController(text: useStored ? stored.number : '');
    _model = TextEditingController(text: useStored ? stored.model : '');
    _color = TextEditingController(text: useStored ? stored.color : '');
    _year = TextEditingController(
      text: useStored && stored.manufacturingYear > 0
          ? '${stored.manufacturingYear}'
          : '',
    );
  }

  @override
  void dispose() {
    _number.dispose();
    _model.dispose();
    _color.dispose();
    _year.dispose();
    super.dispose();
  }

  bool _validate() {
    String? numberError;
    String? modelError;
    String? colorError;
    String? yearError;
    if (_number.text.trim().length < 6) {
      numberError = 'Enter a valid vehicle number';
    }
    if (_model.text.trim().isEmpty) {
      modelError = 'Enter vehicle model';
    }
    if (_color.text.trim().isEmpty) {
      colorError = 'Enter vehicle color';
    }
    final year = int.tryParse(_year.text.trim());
    if (year == null || year < 1990 || year > DateTime.now().year + 1) {
      yearError = 'Enter a valid year';
    }
    setState(() {
      _numberError = numberError;
      _modelError = modelError;
      _colorError = colorError;
      _yearError = yearError;
    });
    return numberError == null &&
        modelError == null &&
        colorError == null &&
        yearError == null;
  }

  Future<void> _continue() async {
    if (_saving || !_validate()) return;
    final year = int.parse(_year.text.trim());
    final rows =
        ref.read(vehicleCategoryCatalogProvider).value ??
            const <VehicleCategory>[];
    VehicleCategory? match;
    for (final row in rows) {
      if (row.name == _categoryName || row.name == _type.label) {
        match = row;
        break;
      }
    }
    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose the vehicle category again before saving.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(riderSessionProvider.notifier).saveVehicle(
            vehicleCategoryId: match.id,
            registration: _number.text.trim(),
            model: _model.text.trim(),
            color: _color.text.trim(),
            manufacturingYear: year,
          );
      if (!mounted) return;
      if (widget.editMode) {
        context.pop();
        return;
      }
      final session = ref.read(riderSessionProvider);
      if (session.onboardingResume) {
        await riderEnterAfterAuth(context, ref);
        return;
      }
      unawaited(context.push(RiderRoutes.driverDetails));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicle details could not be saved.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RiderScaffold(
      appBar: AppBar(
        title: Text(widget.editMode ? 'Edit vehicle details' : 'Vehicle details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      bottom: RiderPrimaryButton(
        label: _saving
            ? 'Saving'
            : (widget.editMode ? 'Save' : 'Continue'),
        onPressed: _saving ? null : _continue,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _categoryName.trim().isEmpty
                  ? 'Vehicle details'
                  : '$_categoryName details',
              style: RiderTextStyles.heading,
            ),
            const SizedBox(height: RiderSpacing.sm),
            Text(
              'Enter accurate details matching your RC document.',
              style: RiderTextStyles.caption,
            ),
            const SizedBox(height: RiderSpacing.xl),
            RiderGlassCard(
              child: Column(
                children: [
                  RiderTextField(
                    controller: _number,
                    label: 'Vehicle number',
                    hint: 'Vehicle number',
                    prefixIcon: Icons.pin_outlined,
                    errorText: _numberError,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: RiderSpacing.lg),
                  RiderTextField(
                    controller: _model,
                    label: 'Vehicle model',
                    hint: 'Vehicle model',
                    prefixIcon: Icons.two_wheeler_rounded,
                    errorText: _modelError,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: RiderSpacing.lg),
                  RiderTextField(
                    controller: _color,
                    label: 'Vehicle color',
                    hint: 'Vehicle color',
                    prefixIcon: Icons.palette_outlined,
                    errorText: _colorError,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: RiderSpacing.lg),
                  RiderTextField(
                    controller: _year,
                    label: 'Manufacturing year',
                    hint: 'Year',
                    prefixIcon: Icons.calendar_today_outlined,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    errorText: _yearError,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
