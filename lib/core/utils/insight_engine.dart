import '../../models/transaction_model.dart';
import '../../models/budget_model.dart';
import '../../models/holding_model.dart';

class Insight {
  final String type; // 'warning' | 'tip' | 'info'
  final String title;
  final String body;
  final String? emoji;

  const Insight({
    required this.type,
    required this.title,
    required this.body,
    this.emoji,
  });
}

class InsightEngine {
  static List<Insight> generate({
    required List<TransactionModel> transactions,
    required List<BudgetStatus> budgetStatuses,
    required List<HoldingModel> holdings,
    required double totalIncome,
    required double totalExpenses,
  }) {
    final insights = <Insight>[];

    // 1. Savings rate
    if (totalIncome > 0) {
      final rate = ((totalIncome - totalExpenses) / totalIncome) * 100;
      if (rate < 10) {
        insights.add(const Insight(
          type: 'warning',
          title: 'Low Savings Rate',
          body: 'You\'re saving less than 10% of your income. Aim for at least 20%.',
          emoji: '⚠️',
        ));
      } else if (rate >= 30) {
        insights.add(Insight(
          type: 'info',
          title: 'Great Savings!',
          body: 'You\'re saving ${rate.toStringAsFixed(0)}% of your income. Keep it up!',
          emoji: '🎉',
        ));
      }
    }

    // 2. Budget alerts
    for (final status in budgetStatuses) {
      if (status.isOver) {
        insights.add(Insight(
          type: 'warning',
          title: 'Over Budget: ${status.budget.category}',
          body: 'You\'ve exceeded your ₹${status.budget.limitAmount.toStringAsFixed(0)} '
              '${status.budget.category} budget by ₹${(status.spent - status.budget.limitAmount).toStringAsFixed(0)}.',
          emoji: '🚨',
        ));
      } else if (status.isWarning) {
        insights.add(Insight(
          type: 'warning',
          title: 'Budget Warning: ${status.budget.category}',
          body: 'You\'ve used ${(status.usageRatio * 100).toStringAsFixed(0)}% of your '
              '${status.budget.category} budget. ₹${status.remaining.toStringAsFixed(0)} remaining.',
          emoji: '⚡',
        ));
      }
    }

    // 3. Top spending category
    final expByCategory = <String, double>{};
    for (final t in transactions.where((t) => t.isExpense)) {
      expByCategory[t.category] = (expByCategory[t.category] ?? 0) + t.amount;
    }
    if (expByCategory.isNotEmpty) {
      final topCat = expByCategory.entries.reduce((a, b) => a.value > b.value ? a : b);
      final pct = totalExpenses > 0 ? (topCat.value / totalExpenses * 100) : 0;
      if (pct > 40) {
        insights.add(Insight(
          type: 'tip',
          title: 'High Concentration in ${topCat.key}',
          body: '${pct.toStringAsFixed(0)}% of your expenses are on ${topCat.key}. '
              'Consider spreading spending across categories.',
          emoji: '💡',
        ));
      }
    }

    // 4. Anomalies
    final byCategory = <String, List<double>>{};
    for (final t in transactions.where((t) => t.isExpense)) {
      byCategory.putIfAbsent(t.category, () => []).add(t.amount);
    }
    for (final entry in byCategory.entries) {
      final amounts = entry.value;
      if (amounts.length < 3) continue;
      final avg = amounts.fold(0.0, (s, a) => s + a) / amounts.length;
      final spikes = amounts.where((a) => a > avg * 2.5).length;
      if (spikes > 0) {
        insights.add(Insight(
          type: 'warning',
          title: 'Unusual Spending in ${entry.key}',
          body: 'You have $spikes unusually large transaction(s) in ${entry.key} '
              '(more than 2.5× the average of ₹${avg.toStringAsFixed(0)}).',
          emoji: '📊',
        ));
      }
    }

    // 5. Portfolio concentration
    if (holdings.isNotEmpty) {
      final totalValue = holdings.fold(0.0, (s, h) => s + h.currentValue);
      for (final h in holdings) {
        if (totalValue > 0 && h.currentValue / totalValue > 0.5) {
          insights.add(Insight(
            type: 'tip',
            title: 'Portfolio Concentration',
            body: '${h.name} makes up ${(h.currentValue / totalValue * 100).toStringAsFixed(0)}% '
                'of your portfolio. Consider diversifying.',
            emoji: '📈',
          ));
        }
      }
    }

    // 6. No investments nudge
    if (holdings.isEmpty && totalIncome > 0) {
      insights.add(const Insight(
        type: 'tip',
        title: 'Start Investing',
        body: 'You have no tracked investments yet. Even small SIPs can grow significantly over time.',
        emoji: '🌱',
      ));
    }

    // 7. No transactions this month
    if (transactions.isEmpty) {
      insights.add(const Insight(
        type: 'info',
        title: 'No Transactions Yet',
        body: 'Add your first transaction to start tracking your finances.',
        emoji: '➕',
      ));
    }

    return insights.take(5).toList(); // show top 5
  }
}
