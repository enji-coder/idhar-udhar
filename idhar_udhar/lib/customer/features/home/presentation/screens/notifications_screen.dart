import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:intl/intl.dart';

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
  bool _loading = true;
  String? _error;
  String? _deletingId;

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
      await ref.read(sessionProvider.notifier).refreshNotices();
      if (mounted) {
        setState(() => _loading = false);
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
          _error = 'Could not load notifications.';
        });
      }
    }
  }

  Future<void> _open(CustomerNotice notice) async {
    if (notice.read) {
      return;
    }
    try {
      await ref.read(sessionProvider.notifier).markNoticeRead(notice.id);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update this notification.')),
        );
      }
    }
  }

  Future<bool> _delete(CustomerNotice notice) async {
    if (_deletingId != null) {
      return false;
    }
    setState(() => _deletingId = notice.id);
    try {
      await ref.read(sessionProvider.notifier).deleteNotice(notice.id);
      return true;
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
      return false;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete this notification.')),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _deletingId = null);
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
          Expanded(child: _body(notices)),
        ],
      ),
    );
  }

  Widget _body(List<CustomerNotice> notices) {
    if (_loading && notices.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && notices.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }
    if (notices.isEmpty) {
      return Center(
        child: Text(
          'No notifications yet.',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
      );
    }
    return ListView.separated(
      itemCount: notices.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final CustomerNotice notice = notices[index];
        final String title = notice.title.trim().isEmpty
            ? 'Notification'
            : notice.title.trim();
        final String body = notice.body.trim();
        return Dismissible(
          key: ValueKey<String>(notice.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => _delete(notice),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: const BoxDecoration(
              color: AppColors.danger,
              borderRadius: AppRadius.lgAll,
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.white,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _open(notice),
              child: GlassContainer(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!notice.read) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.info,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: notice.read
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                            ),
                          ),
                          if (body.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              body,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            _whenLabel(notice.createdAt),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _whenLabel(DateTime? createdAt) {
    if (createdAt == null) {
      return '—';
    }
    final DateTime local = createdAt.toLocal();
    final String date = DateFormat('d MMM yyyy').format(local);
    final String time = DateFormat('h:mm a').format(local);
    return '$date · $time';
  }
}
