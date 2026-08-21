import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/local/rider_permissions.dart';
import '../../data/local/rider_prefs.dart';
import '../../routing/rider_routes.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_glass_card.dart';
import '../../widgets/rider_primary_button.dart';
import '../../widgets/rider_scaffold.dart';
import '../../widgets/rider_section_header.dart';

class PermissionSetupScreen extends StatefulWidget {
  const PermissionSetupScreen({
    super.key,
    this.continueToDashboard = true,
  });

  /// After all required permissions: Dashboard (login/session) or registration complete.
  final bool continueToDashboard;

  @override
  State<PermissionSetupScreen> createState() => _PermissionSetupScreenState();
}

class _PermissionSetupScreenState extends State<PermissionSetupScreen>
    with WidgetsBindingObserver {
  bool _locationGranted = false;
  bool _cameraGranted = false;
  bool _notificationGranted = false;
  bool _overlayGranted = false;
  bool _loadingLocation = false;
  bool _loadingCamera = false;
  bool _loadingNotification = false;
  bool _loadingOverlay = false;

  bool _locationPermanent = false;
  bool _cameraPermanent = false;
  bool _notificationPermanent = false;

  bool get _isAndroid => RiderPermissions.isAndroid;

  bool get _allGranted =>
      _locationGranted &&
      _cameraGranted &&
      _notificationGranted &&
      (!_isAndroid || _overlayGranted);

  bool get _anyPermanent =>
      _locationPermanent || _cameraPermanent || _notificationPermanent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshStatuses());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatuses();
    }
  }

  Future<void> _refreshStatuses() async {
    final location = await RiderPermissions.safeStatus(Permission.locationWhenInUse);
    final camera = await RiderPermissions.safeStatus(Permission.camera);
    final notification = await RiderPermissions.safeStatus(Permission.notification);
    var overlay = false;
    if (_isAndroid) {
      overlay = (await RiderPermissions.safeStatus(Permission.systemAlertWindow))
          .isGranted;
    }
    if (!mounted) return;
    setState(() {
      _locationGranted = RiderPermissions.isUsable(location);
      _cameraGranted = RiderPermissions.isUsable(camera);
      _notificationGranted = RiderPermissions.isUsable(notification);
      _overlayGranted = overlay;
      _locationPermanent = location.isPermanentlyDenied;
      _cameraPermanent = camera.isPermanentlyDenied;
      _notificationPermanent = notification.isPermanentlyDenied;
    });
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: RiderColors.secondary,
        content: Text(
          message,
          style: RiderTextStyles.bodyMedium.copyWith(
            color: RiderColors.textOnPrimary,
          ),
        ),
      ),
    );
  }

  Future<void> _handleResult(PermissionStatus status, String label) async {
    if (RiderPermissions.isUsable(status)) return;
    if (status.isPermanentlyDenied) {
      _snack(
        'Please enable the required permission from Settings to continue.',
      );
      try {
        await openAppSettings();
      } catch (_) {}
      return;
    }
    _snack(
      'Required permission is needed to continue using IDHAR UDHAR PARTNER.',
    );
  }

  Future<void> _requestLocation() async {
    setState(() => _loadingLocation = true);
    final status = await RiderPermissions.safeRequest(Permission.locationWhenInUse);
    if (!mounted) return;
    setState(() {
      _loadingLocation = false;
      _locationGranted = RiderPermissions.isUsable(status);
      _locationPermanent = status.isPermanentlyDenied;
    });
    await _handleResult(status, 'Location');
  }

  Future<void> _requestCamera() async {
    setState(() => _loadingCamera = true);
    final status = await RiderPermissions.safeRequest(Permission.camera);
    if (!mounted) return;
    setState(() {
      _loadingCamera = false;
      _cameraGranted = RiderPermissions.isUsable(status);
      _cameraPermanent = status.isPermanentlyDenied;
    });
    await _handleResult(status, 'Camera');
  }

  Future<void> _requestNotifications() async {
    setState(() => _loadingNotification = true);
    final status = await RiderPermissions.safeRequest(Permission.notification);
    if (!mounted) return;
    setState(() {
      _loadingNotification = false;
      _notificationGranted = RiderPermissions.isUsable(status);
      _notificationPermanent = status.isPermanentlyDenied;
    });
    await _handleResult(status, 'Notifications');
  }

  Future<void> _requestOverlay() async {
    if (!_isAndroid) {
      _snack('Display over other apps is only required on Android.');
      return;
    }
    setState(() => _loadingOverlay = true);
    try {
      // Special permission: opens the system "Appear on top" / overlay page.
      await Permission.systemAlertWindow.request();
    } catch (_) {
      try {
        await openAppSettings();
      } catch (_) {}
    }
    if (!mounted) return;
    final granted =
        (await RiderPermissions.safeStatus(Permission.systemAlertWindow))
            .isGranted;
    setState(() {
      _loadingOverlay = false;
      _overlayGranted = granted;
    });
    if (!granted) {
      _snack(
        'Enable “Display over other apps” in system settings, then return here.',
      );
    }
  }

  Future<void> _tryAgain() async {
    await _refreshStatuses();
    if (_allGranted) {
      await _continue();
      return;
    }
    if (_anyPermanent) {
      _snack(
        'Please enable the required permission from Settings to continue.',
      );
      try {
        await openAppSettings();
      } catch (_) {}
      return;
    }
    if (!_locationGranted) await _requestLocation();
    if (!_cameraGranted) await _requestCamera();
    if (!_notificationGranted) await _requestNotifications();
    if (_isAndroid && !_overlayGranted) await _requestOverlay();
    await _refreshStatuses();
    if (!mounted) return;
    if (_allGranted) {
      await _continue();
      return;
    }
    _snack(
      'Required permission is needed to continue using IDHAR UDHAR PARTNER.',
    );
  }

  Future<void> _continue() async {
    final granted = await RiderPermissions.areAllRequiredGranted();
    if (!mounted) return;
    if (!granted) {
      _snack(
        'Required permission is needed to continue using IDHAR UDHAR PARTNER.',
      );
      return;
    }
    await RiderPrefs.setInitialSetupComplete();
    if (!mounted) return;
    if (widget.continueToDashboard) {
      context.go(RiderRoutes.dashboard);
    } else {
      await context.push(RiderRoutes.registrationComplete);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.continueToDashboard,
      child: RiderScaffold(
      appBar: AppBar(
        title: const Text('Permissions'),
        leading: widget.continueToDashboard
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              ),
        automaticallyImplyLeading: !widget.continueToDashboard,
      ),
      bottom: RiderPrimaryButton(
        label: _allGranted
            ? 'Continue'
            : (_anyPermanent ? 'Open Settings' : 'Try Again'),
        onPressed: _allGranted ? _continue : _tryAgain,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Enable access', style: RiderTextStyles.heading),
            const SizedBox(height: RiderSpacing.sm),
            Text(
              'All required permissions must be allowed before you can continue using IDHAR UDHAR PARTNER.',
              style: RiderTextStyles.caption,
            ),
            const SizedBox(height: RiderSpacing.xl),
            _PermissionCard(
              title: 'Location Access',
              icon: Icons.location_on_rounded,
              granted: _locationGranted,
              loading: _loadingLocation,
              explanation:
                  'IDHAR UDHAR Rider needs your location to provide delivery and navigation services.',
              reasons: const [
                'Live tracking',
                'Pickup navigation',
                'Customer location',
              ],
              actionLabel: _locationPermanent ? 'Open Settings' : 'Allow Location',
              onAllow: _requestLocation,
            ),
            const SizedBox(height: RiderSpacing.md),
            _PermissionCard(
              title: 'Camera Access',
              icon: Icons.photo_camera_outlined,
              granted: _cameraGranted,
              loading: _loadingCamera,
              explanation:
                  'Camera is used to capture Aadhaar, PAN, licence, RC, and bank proof photos.',
              reasons: const [
                'Document capture',
                'Clear photo uploads',
              ],
              actionLabel: _cameraPermanent ? 'Open Settings' : 'Allow Camera',
              onAllow: _requestCamera,
            ),
            const SizedBox(height: RiderSpacing.md),
            _PermissionCard(
              title: 'Notifications',
              icon: Icons.notifications_active_rounded,
              granted: _notificationGranted,
              loading: _loadingNotification,
              explanation:
                  'IDHAR UDHAR Rider uses notifications to alert you about new deliveries.',
              reasons: const [
                'New order alerts',
                'Order updates',
              ],
              actionLabel:
                  _notificationPermanent ? 'Open Settings' : 'Allow Notifications',
              onAllow: _requestNotifications,
            ),
            if (_isAndroid) ...[
              const SizedBox(height: RiderSpacing.md),
              _PermissionCard(
                title: 'Display over other apps',
                icon: Icons.layers_outlined,
                granted: _overlayGranted,
                loading: _loadingOverlay,
                explanation:
                    'Android requires this special setting so order alerts can appear while you use navigation or other apps. This opens system settings — it is not a normal permission popup.',
                reasons: const [
                  'Incoming order alerts',
                  'Appear on top while navigating',
                ],
                actionLabel: 'Open Settings',
                onAllow: _requestOverlay,
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.title,
    required this.icon,
    required this.granted,
    required this.loading,
    required this.reasons,
    required this.onAllow,
    required this.actionLabel,
    this.explanation,
  });

  final String title;
  final IconData icon;
  final bool granted;
  final bool loading;
  final List<String> reasons;
  final VoidCallback onAllow;
  final String actionLabel;
  final String? explanation;

  @override
  Widget build(BuildContext context) {
    return RiderGlassCard(
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
                child: Icon(icon, color: RiderColors.primary),
              ),
              const SizedBox(width: RiderSpacing.md),
              Expanded(
                child: Text(title, style: RiderTextStyles.title.copyWith(fontSize: 16)),
              ),
              RiderStatusChip(
                label: granted ? 'Allowed' : 'Required',
                tone: granted ? RiderChipTone.success : RiderChipTone.warning,
              ),
            ],
          ),
          if (explanation != null) ...[
            const SizedBox(height: RiderSpacing.md),
            Text(explanation!, style: RiderTextStyles.caption),
          ],
          const SizedBox(height: RiderSpacing.md),
          Text('Required for:', style: RiderTextStyles.caption),
          const SizedBox(height: RiderSpacing.sm),
          for (final reason in reasons)
            Padding(
              padding: const EdgeInsets.only(bottom: RiderSpacing.xs),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: RiderColors.primary,
                  ),
                  const SizedBox(width: RiderSpacing.sm),
                  Expanded(
                    child: Text(reason, style: RiderTextStyles.bodyMedium),
                  ),
                ],
              ),
            ),
          const SizedBox(height: RiderSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: granted || loading ? null : onAllow,
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      granted ? 'Granted' : actionLabel,
                      style: RiderTextStyles.bodyMedium.copyWith(
                        color: granted
                            ? RiderColors.success
                            : RiderColors.primary,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
