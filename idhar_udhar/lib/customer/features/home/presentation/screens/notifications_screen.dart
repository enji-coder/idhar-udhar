import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/notifications_api.dart';

import '../../../../core/state/session_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/glass_page_scaffold.dart';
import '../../../../shared/widgets/iu_back_button.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  NotificationPreferences? _prefs;
  bool _loadingPrefs = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_load());
    });
  }

  Future<void> _load() async {
    await ref.read(sessionProvider.notifier).refreshNotices();
    try {
      final NotificationPreferences prefs =
          await ref.read(notificationsApiProvider).getPreferences();
      if (mounted) {
        setState(() {
          _prefs = prefs;
          _loadingPrefs = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingPrefs = false);
      }
    }
  }

  Future<void> _setPrefs({required bool inApp, required bool push}) async {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<CustomerNotice> notices = ref.watch(sessionProvider).notices;
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
                  'Notifications',
                  style: AppTextStyles.headingS,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (notices.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () =>
                    ref.read(sessionProvider.notifier).markAllNoticesRead(),
                child: const Text('Mark all read'),
              ),
            ),
          Expanded(
            child: notices.isEmpty
                ? Center(
                    child: Text(
                      'No notifications yet.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: notices.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final CustomerNotice notice = notices[index];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => ref
                              .read(sessionProvider.notifier)
                              .markNoticeRead(notice.id),
                          child: GlassContainer(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notice.title,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: notice.read
                                        ? FontWeight.w500
                                        : FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  notice.body,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (!_loadingPrefs && _prefs != null) ...[
            const SizedBox(height: AppSpacing.md),
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
                    subtitle: const Text('Delivery comes in a later phase.'),
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
        ],
      ),
    );
  }
}
