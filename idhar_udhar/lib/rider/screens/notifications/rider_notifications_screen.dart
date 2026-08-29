import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';

import '../../state/rider_session.dart';
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
              itemCount: notices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final notice = notices[index];
                return InkWell(
                  onTap: () async {
                    await ref
                        .read(notificationsApiProvider)
                        .markRead(notice.id);
                    await ref
                        .read(riderSessionProvider.notifier)
                        .refreshNotices();
                  },
                  child: RiderGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notice.title,
                          style: RiderTextStyles.title,
                        ),
                        const SizedBox(height: 6),
                        Text(notice.body, style: RiderTextStyles.caption),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
