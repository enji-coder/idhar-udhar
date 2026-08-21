class RiderEarnings {
  const RiderEarnings({
    required this.todayAmount,
    required this.yesterdayChangePercent,
    required this.completedOrders,
    required this.onlineDuration,
    required this.targetOrders,
    required this.targetOrdersGoal,
    required this.targetAmount,
    required this.targetAmountGoal,
    required this.incentiveProgress,
    required this.incentiveGoal,
    required this.recentEarnings,
    this.weeklyDeliveries = 42,
    this.weeklyEarnings = 8450,
    this.monthlyDeliveries = 168,
    this.monthlyEarnings = 32100,
  });

  final double todayAmount;
  final double yesterdayChangePercent;
  final int completedOrders;
  final Duration onlineDuration;
  final int targetOrders;
  final int targetOrdersGoal;
  final double targetAmount;
  final double targetAmountGoal;
  final double incentiveProgress;
  final double incentiveGoal;
  final List<RecentEarningItem> recentEarnings;
  final int weeklyDeliveries;
  final double weeklyEarnings;
  final int monthlyDeliveries;
  final double monthlyEarnings;

  double get orderProgress =>
      targetOrdersGoal == 0 ? 0 : targetOrders / targetOrdersGoal;

  double get amountProgress =>
      targetAmountGoal == 0 ? 0 : targetAmount / targetAmountGoal;

  double get incentiveRatio =>
      incentiveGoal == 0 ? 0 : incentiveProgress / incentiveGoal;
}

class RecentEarningItem {
  const RecentEarningItem({
    required this.label,
    required this.amount,
    required this.timeLabel,
  });

  final String label;
  final double amount;
  final String timeLabel;
}

class VerificationStep {
  const VerificationStep({
    required this.title,
    required this.state,
  });

  final String title;
  final VerificationStepState state;
}

enum VerificationStepState { done, active, pending }
