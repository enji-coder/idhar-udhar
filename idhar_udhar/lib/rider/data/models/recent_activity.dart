/// Recent completed delivery shown on Home / Orders tabs.
class RecentActivityItem {
  const RecentActivityItem({
    required this.orderId,
    required this.pickup,
    required this.drop,
    required this.amount,
    this.status = 'Completed',
    this.timeLabel = '',
  });

  final String orderId;
  final String pickup;
  final String drop;
  final double amount;
  final String status;
  final String timeLabel;

  String get routeLabel => '$pickup → $drop';
}
