import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/notifications_api.dart';

import '../../../../core/theme/theme.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/glass_page_scaffold.dart';
import '../../../../shared/widgets/iu_back_button.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  NotificationPreferences? _prefs;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_load());
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final NotificationPreferences prefs =
          await ref.read(notificationsApiProvider).getPreferences();
      if (mounted) {
        setState(() {
          _prefs = prefs;
          _loading = false;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load notification settings.';
        });
      }
    }
  }

  Future<void> _setPrefs({required bool inApp, required bool push}) async {
    final NotificationPreferences? previous = _prefs;
    try {
      final NotificationPreferences prefs =
          await ref.read(notificationsApiProvider).updatePreferences(
                inAppEnabled: inApp,
                pushEnabled: push,
              );
      if (mounted) {
        setState(() => _prefs = prefs);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _prefs = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _prefs = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update notification settings.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassPageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IuBackButton(),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Notification settings',
                  style: AppTextStyles.headingS,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null || _prefs == null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error ?? 'Could not load notification settings.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextButton(onPressed: _load, child: const Text('Try again')),
                  ],
                ),
              ),
            )
          else
            GlassContainer(
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('In-app notifications'),
                    value: _prefs!.inAppEnabled,
                    onChanged: (value) => _setPrefs(
                      inApp: value,
                      push: _prefs!.pushEnabled,
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Push notifications'),
                    value: _prefs!.pushEnabled,
                    onChanged: (value) => _setPrefs(
                      inApp: _prefs!.inAppEnabled,
                      push: value,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
