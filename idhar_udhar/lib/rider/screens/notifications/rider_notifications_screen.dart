import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/notifications_api.dart';
import 'package:intl/intl.dart';

import '../../state/rider_session.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_glass_card.dart';
import '../../widgets/rider_scaffold.dart';

class RiderNotificationsScreen extends ConsumerStatefulWidget {
  const RiderNotificationsScreen({super.key});

  @override
  ConsumerState<RiderNotificationsScreen> createState() =>
      _RiderNotificationsScreenState();
}

class _RiderNotificationsScreenState
    extends ConsumerState<RiderNotificationsScreen> {
  static final DateFormat _stamp = DateFormat('d MMM yyyy, h:mm a');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(riderSessionProvider.notifier).refreshNotices());
    });
  }

  @override
  Widget build(BuildContext context) {
    final notices = ref.watch(riderSessionProvider).notices;
    return RiderScaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: notices.isEmpty
          ? Center(
              child: Text(
                'No notifications yet.',
                style: RiderTextStyles.caption,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: RiderSpacing.sm),
              itemCount: notices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final ApiNotification notice = notices[index];
                final bool unread = !notice.isRead;
                return InkWell(
                  onTap: () async {
                    if (!notice.isRead) {
                      await ref
                          .read(notificationsApiProvider)
                          .markRead(notice.id);
                      await ref
                          .read(riderSessionProvider.notifier)
                          .refreshNotices();
                    }
                  },
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: unread
                          ? RiderColors.primary.withValues(alpha: 0.08)
                          : Colors.transparent,
                    ),
                    child: RiderGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  notice.title,
                                  style: RiderTextStyles.title.copyWith(
                                    fontWeight: unread
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: RiderColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (unread)
                                Container(
                                  margin:
                                      const EdgeInsets.only(left: 8, top: 4),
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: RiderColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            notice.body,
                            style: RiderTextStyles.caption.copyWith(
                              color: unread
                                  ? RiderColors.textPrimary
                                  : RiderColors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _stamp.format(notice.createdAt.toLocal()),
                            style: RiderTextStyles.caption.copyWith(
                              color: RiderColors.hint,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
