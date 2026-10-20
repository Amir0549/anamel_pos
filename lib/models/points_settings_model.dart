class PointsSettings {
  final bool isEnabled;
  final int pointsAwarded;
  final double amountStep;

  const PointsSettings({
    this.isEnabled = true,
    this.pointsAwarded = 1,
    this.amountStep = 10.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': 1,
      'is_enabled': isEnabled ? 1 : 0,
      'points_awarded': pointsAwarded,
      'amount_step': amountStep,
    };
  }

  factory PointsSettings.fromMap(Map<String, dynamic> map) {
    return PointsSettings(
      isEnabled: (map['is_enabled'] as int? ?? 1) == 1,
      pointsAwarded: (map['points_awarded'] as num?)?.toInt() ?? 1,
      amountStep: (map['amount_step'] as num?)?.toDouble() ?? 10.0,
    );
  }

  PointsSettings copyWith({
    bool? isEnabled,
    int? pointsAwarded,
    double? amountStep,
  }) {
    return PointsSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      pointsAwarded: pointsAwarded ?? this.pointsAwarded,
      amountStep: amountStep ?? this.amountStep,
    );
  }

  /// حساب عدد النقاط المستحقة لمبلغ منفق
  int calculatePoints(double amountSpent) {
    if (!isEnabled || amountStep <= 0 || amountSpent <= 0) return 0;
    return ((amountSpent / amountStep) * pointsAwarded).floor();
  }
}
