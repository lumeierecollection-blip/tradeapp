class GoalPlan {
  final String id;
  final String mindset;
  final int week;
  final int tradesPerDay;
  final int tradesPerWeek;
  final double riskPerTradePct;
  final double weeklyLossLimitPct;
  final double weeklyTargetPct;
  final double accuracyGoalPct;
  final String summary;

  const GoalPlan({
    required this.id,
    required this.mindset,
    required this.week,
    required this.tradesPerDay,
    required this.tradesPerWeek,
    required this.riskPerTradePct,
    required this.weeklyLossLimitPct,
    required this.weeklyTargetPct,
    required this.accuracyGoalPct,
    required this.summary,
  });

  static const List<GoalPlan> presets = [
    GoalPlan(
      id: 'realistic-w1',
      mindset: 'Realistic',
      week: 1,
      tradesPerDay: 2,
      tradesPerWeek: 7,
      riskPerTradePct: 2,
      weeklyLossLimitPct: 10,
      weeklyTargetPct: 3,
      accuracyGoalPct: 50,
      summary:
          'Slow and steady: max 2 buys a day, close each one before the next. '
          'Learn the fees, protect the capital, prove the strategy.',
    ),
    GoalPlan(
      id: 'optimistic-w1',
      mindset: 'Optimistic',
      week: 1,
      tradesPerDay: 3,
      tradesPerWeek: 12,
      riskPerTradePct: 3,
      weeklyLossLimitPct: 15,
      weeklyTargetPct: 12,
      accuracyGoalPct: 60,
      summary:
          'More active: up to 3 buys a day. Only worth it if week-1 accuracy '
          'stays above 50% — otherwise it is just feeding fees.',
    ),
    GoalPlan(
      id: 'realistic-w2',
      mindset: 'Realistic',
      week: 2,
      tradesPerDay: 2,
      tradesPerWeek: 8,
      riskPerTradePct: 2,
      weeklyLossLimitPct: 8,
      weeklyTargetPct: 5,
      accuracyGoalPct: 52,
      summary:
          'Same pace as week 1, slightly higher accuracy bar. Reinvest only '
          'what you earned — the base \$5 stays protected.',
    ),
    GoalPlan(
      id: 'optimistic-w2',
      mindset: 'Optimistic',
      week: 2,
      tradesPerDay: 4,
      tradesPerWeek: 14,
      riskPerTradePct: 3,
      weeklyLossLimitPct: 12,
      weeklyTargetPct: 18,
      accuracyGoalPct: 60,
      summary:
          'Max activity. Reserve this for a week-1 that actually hit its '
          'target — otherwise drop back to the realistic plan.',
    ),
  ];

  static GoalPlan byId(String id) =>
      presets.firstWhere((p) => p.id == id, orElse: () => presets.first);
}
