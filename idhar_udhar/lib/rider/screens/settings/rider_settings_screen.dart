import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_glass_card.dart';
import '../../widgets/rider_primary_button.dart';
import '../../widgets/rider_scaffold.dart';
import '../../widgets/rider_section_header.dart';

class RiderSettingsScreen extends StatefulWidget {
  const RiderSettingsScreen({super.key});

  @override
  State<RiderSettingsScreen> createState() => _RiderSettingsScreenState();
}

class _RiderSettingsScreenState extends State<RiderSettingsScreen>
    with WidgetsBindingObserver {
  bool _overlayGranted = false;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (!_isAndroid) return;
    try {
      final granted = await Permission.systemAlertWindow.isGranted;
      if (mounted) setState(() => _overlayGranted = granted);
    } catch (_) {}
  }

  Future<void> _openOverlaySettings() async {
    if (!_isAndroid) return;
    try {
      await Permission.systemAlertWindow.request();
    } catch (_) {
      try {
        await openAppSettings();
      } catch (_) {}
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return RiderScaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        children: [
          if (_isAndroid)
            RiderGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const RiderSectionHeader(title: 'Display over other apps'),
                  const SizedBox(height: RiderSpacing.sm),
                  Text(
                    'Android special permission. Opens system settings so order alerts can appear on top of other apps.',
                    style: RiderTextStyles.caption,
                  ),
                  const SizedBox(height: RiderSpacing.md),
                  RiderStatusChip(
                    label: _overlayGranted ? 'Enabled' : 'Not enabled',
                    tone: _overlayGranted
                        ? RiderChipTone.success
                        : RiderChipTone.warning,
                  ),
                  const SizedBox(height: RiderSpacing.lg),
                  RiderPrimaryButton(
                    label: 'Open system settings',
                    onPressed: _openOverlaySettings,
                  ),
                ],
              ),
            )
          else
            RiderGlassCard(
              child: Text(
                'Display over other apps is Android-only and is not requested on this platform.',
                style: RiderTextStyles.caption,
              ),
            ),
        ],
      ),
    );
  }
}
