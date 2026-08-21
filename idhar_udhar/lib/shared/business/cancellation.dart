import 'fare_engine.dart';
import 'order_lifecycle.dart';

enum CancellationActor { customer, rider }

/// Stages taken from the current trip lifecycle. Do not invent extra stages.
enum CancellationStage {
  beforeAccept,
  afterAccept,
  afterArrivePickup,
  afterPickup,
  inTransit,
}

extension CancellationStageX on CancellationStage {
  String get label {
    switch (this) {
      case CancellationStage.beforeAccept:
        return 'Before rider accepts';
      case CancellationStage.afterAccept:
        return 'After rider accepts';
      case CancellationStage.afterArrivePickup:
        return 'After rider reaches pickup';
      case CancellationStage.afterPickup:
        return 'After pickup / parcel collected';
      case CancellationStage.inTransit:
        return 'During delivery / in transit';
    }
  }
}

class CancellationRule {
  const CancellationRule({
    this.enabled = true,
    this.fee = 0,
    this.riderSharePercent = 0,
    this.companySharePercent = 100,
  });

  final bool enabled;
  final double fee;
  final double riderSharePercent;
  final double companySharePercent;

  bool get sharesValid =>
      FareEngine.round2(riderSharePercent + companySharePercent) == 100 &&
      riderSharePercent >= 0 &&
      companySharePercent >= 0;

  CancellationRule copyWith({
    bool? enabled,
    double? fee,
    double? riderSharePercent,
    double? companySharePercent,
  }) {
    return CancellationRule(
      enabled: enabled ?? this.enabled,
      fee: fee ?? this.fee,
      riderSharePercent: riderSharePercent ?? this.riderSharePercent,
      companySharePercent: companySharePercent ?? this.companySharePercent,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'enabled': enabled,
        'fee': fee,
        'riderSharePercent': riderSharePercent,
        'companySharePercent': companySharePercent,
      };

  factory CancellationRule.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CancellationRule();
    return CancellationRule(
      enabled: json['enabled'] as bool? ?? true,
      fee: (json['fee'] as num?)?.toDouble() ?? 0,
      riderSharePercent: (json['riderSharePercent'] as num?)?.toDouble() ?? 0,
      companySharePercent:
          (json['companySharePercent'] as num?)?.toDouble() ?? 100,
    );
  }
}

class CancellationConfig {
  const CancellationConfig({
    required this.customer,
    required this.rider,
    this.versionId = 'cancel_v1',
  });

  final Map<CancellationStage, CancellationRule> customer;
  final Map<CancellationStage, CancellationRule> rider;
  final String versionId;

  /// Default: fee ₹0. Customer may cancel before/at assignment.
  /// Later customer stages and all rider stages stay disabled until Admin enables them.
  static CancellationConfig defaults() {
    CancellationRule before() => const CancellationRule(
          enabled: true,
          fee: 0,
          riderSharePercent: 0,
          companySharePercent: 100,
        );
    CancellationRule off() => const CancellationRule(
          enabled: false,
          fee: 0,
          riderSharePercent: 0,
          companySharePercent: 100,
        );
    return CancellationConfig(
      customer: <CancellationStage, CancellationRule>{
        CancellationStage.beforeAccept: before(),
        CancellationStage.afterAccept: before(),
        CancellationStage.afterArrivePickup: off(),
        CancellationStage.afterPickup: off(),
        CancellationStage.inTransit: off(),
      },
      rider: <CancellationStage, CancellationRule>{
        for (final CancellationStage stage in CancellationStage.values)
          stage: off(),
      },
    );
  }

  CancellationRule ruleFor(CancellationActor actor, CancellationStage stage) {
    final Map<CancellationStage, CancellationRule> map =
        actor == CancellationActor.customer ? customer : rider;
    return map[stage] ?? const CancellationRule(enabled: false);
  }

  bool get isValid {
    for (final CancellationRule rule in [...customer.values, ...rider.values]) {
      if (!rule.sharesValid) return false;
    }
    return true;
  }
}

class CancellationQuote {
  const CancellationQuote({
    required this.allowed,
    required this.stage,
    required this.fee,
    required this.riderSharePercent,
    required this.companySharePercent,
    required this.riderAmount,
    required this.companyAmount,
    required this.message,
  });

  final bool allowed;
  final CancellationStage stage;
  final double fee;
  final double riderSharePercent;
  final double companySharePercent;
  final double riderAmount;
  final double companyAmount;
  final String message;
}

abstract final class CancellationEngine {
  static CancellationStage stageFor(CanonicalOrderStatus status) {
    switch (status) {
      case CanonicalOrderStatus.created:
      case CanonicalOrderStatus.searching:
      case CanonicalOrderStatus.offered:
        return CancellationStage.beforeAccept;
      case CanonicalOrderStatus.assigned:
        return CancellationStage.afterAccept;
      case CanonicalOrderStatus.enRoutePickup:
      case CanonicalOrderStatus.arrivedPickup:
        return CancellationStage.afterArrivePickup;
      case CanonicalOrderStatus.pickedUp:
        return CancellationStage.afterPickup;
      case CanonicalOrderStatus.inTransit:
      case CanonicalOrderStatus.nearDrop:
      case CanonicalOrderStatus.deliveryAttempt:
        return CancellationStage.inTransit;
      case CanonicalOrderStatus.delivered:
      case CanonicalOrderStatus.cancelled:
      case CanonicalOrderStatus.receiverUnavailable:
      case CanonicalOrderStatus.failedDelivery:
      case CanonicalOrderStatus.parcelAtCompanyOffice:
      case CanonicalOrderStatus.resendRequested:
      case CanonicalOrderStatus.resendInProgress:
      case CanonicalOrderStatus.resendCompleted:
        return CancellationStage.inTransit;
    }
  }

  static CancellationQuote quote({
    required CancellationActor actor,
    required CanonicalOrderStatus status,
    CancellationConfig? config,
  }) {
    final CancellationConfig rules = config ?? CancellationConfig.defaults();
    final CancellationStage stage = stageFor(status);
    if (OrderLifecycle.terminal.contains(status) ||
        status == CanonicalOrderStatus.cancelled) {
      return CancellationQuote(
        allowed: false,
        stage: stage,
        fee: 0,
        riderSharePercent: 0,
        companySharePercent: 100,
        riderAmount: 0,
        companyAmount: 0,
        message: 'Cancellation not available at this stage',
      );
    }
    final CancellationRule rule = rules.ruleFor(actor, stage);
    if (!rule.enabled) {
      return CancellationQuote(
        allowed: false,
        stage: stage,
        fee: 0,
        riderSharePercent: rule.riderSharePercent,
        companySharePercent: rule.companySharePercent,
        riderAmount: 0,
        companyAmount: 0,
        message: 'Cancellation not available at this stage',
      );
    }
    final double fee = FareEngine.round2(rule.fee);
    final double riderAmount =
        FareEngine.round2(fee * rule.riderSharePercent / 100);
    final double companyAmount = FareEngine.round2(fee - riderAmount);
    return CancellationQuote(
      allowed: true,
      stage: stage,
      fee: fee,
      riderSharePercent: rule.riderSharePercent,
      companySharePercent: rule.companySharePercent,
      riderAmount: riderAmount,
      companyAmount: companyAmount,
      message: fee == 0
          ? 'Cancellation Fee: ₹0'
          : 'Cancellation Fee: ₹${fee.toStringAsFixed(0)}',
    );
  }
}
