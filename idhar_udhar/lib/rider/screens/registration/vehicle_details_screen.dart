import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/dummy/dummy_rider_data.dart';
import '../../data/dummy/dummy_rider_repository.dart';
import '../../data/models/vehicle_info.dart';
import '../../routing/rider_routes.dart';
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

  @override
  void initState() {
    super.initState();
    final v = widget.editMode
        ? ref.read(riderVehicleProvider)
        : DummyRiderData.vehicle;
    _type = widget.vehicleType ??
        (widget.categoryName != null
            ? RiderVehicleTypeX.fromLabel(widget.categoryName)
            : v.type);
    _categoryName = widget.categoryName ?? v.categoryName ?? _type.label;
    _number = TextEditingController(text: v.number);
    _model = TextEditingController(text: v.model);
    _color = TextEditingController(text: v.color);
    _year = TextEditingController(text: '${v.manufacturingYear}');
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

  void _continue() {
    if (!_validate()) return;
    final year = int.parse(_year.text.trim());
    ref.read(riderVehicleProvider.notifier).state = VehicleInfo(
      type: _type,
      categoryName: _categoryName,
      number: _number.text.trim(),
      model: _model.text.trim(),
      color: _color.text.trim(),
      manufacturingYear: year,
    );
    if (widget.editMode) {
      context.pop();
      return;
    }
    context.push(RiderRoutes.driverDetails);
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
        label: widget.editMode ? 'Save' : 'Continue',
        onPressed: _continue,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('$_categoryName details', style: RiderTextStyles.heading),
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
                    hint: 'GJ 05 AB 1234',
                    prefixIcon: Icons.pin_outlined,
                    errorText: _numberError,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: RiderSpacing.lg),
                  RiderTextField(
                    controller: _model,
                    label: 'Vehicle model',
                    hint: 'Honda Shine',
                    prefixIcon: Icons.two_wheeler_rounded,
                    errorText: _modelError,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: RiderSpacing.lg),
                  RiderTextField(
                    controller: _color,
                    label: 'Vehicle color',
                    hint: 'Black',
                    prefixIcon: Icons.palette_outlined,
                    errorText: _colorError,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: RiderSpacing.lg),
                  RiderTextField(
                    controller: _year,
                    label: 'Manufacturing year',
                    hint: '2023',
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
