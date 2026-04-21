import '../../models/transaction_model.dart';
import '../../models/budget_model.dart';
import '../../models/holding_model.dart';

class Insight {
  final String type; // 'warning' | 'tip' | 'info' | 'positive'
  final String title;
  final String body;
  final String? emoji;
  final int priority; // lower = shown first

  const Insight({
    required this.type,
    required this.title,
    required this.body,
    this.emoji,
    this.priority = 5,
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
    final now = DateTime.now();
    final expenses = transactions.where((t) => t.isExpense).toList();

    // ── 1. Spending velocity / end-of-month forecast ─────────────────────────
    if (expenses.isNotEmpty && now.day > 1) {
      final dailyAvg = totalExpenses / now.day;
      final daysLeft  = _daysInMonth(now.year, now.month) - now.day;
      final forecast  = totalExpenses + (dailyAvg * daysLeft);
      if (totalIncome > 0 && forecast > totalIncome * 0.9) {
        insights.add(Insight(
          type: 'warning', priority: 1, emoji: '📉',
          title: 'Overspend Risk This Month',
          body: 'At your daily rate of ₹${dailyAvg.toStringAsFixed(0)}/day, '
              'you\'re on track to spend ₹${forecast.toStringAsFixed(0)} — '
              '${((forecast / totalIncome - 1) * 100).toStringAsFixed(0)}% '
              '${forecast > totalIncome ? 'more than' : 'close to'} your income.',
        ));
      }
    }

    // ── 2. Savings rate with nuanced messaging ───────────────────────────────
    if (totalIncome > 0) {
      final rate = ((totalIncome - totalExpenses) / totalIncome) * 100;
      if (rate < 0) {
        insights.add(Insight(
          type: 'warning', priority: 1, emoji: '🚨',
          title: 'Spending Exceeds Income',
          body: 'You\'ve spent ₹${(totalExpenses - totalIncome).toStringAsFixed(0)} more than '
              'you earned this month. Review your expenses immediately.',
        ));
      } else if (rate < 10) {
        insights.add(Insight(
          type: 'warning', priority: 2, emoji: '⚠️',
          title: 'Very Low Savings — ${rate.toStringAsFixed(0)}%',
          body: 'Financial experts recommend saving 20–30% of income. '
              'You\'re at ${rate.toStringAsFixed(0)}%. Cutting one category could make a big difference.',
        ));
      } else if (rate >= 30 && rate < 50) {
        insights.add(Insight(
          type: 'positive', priority: 6, emoji: '🎉',
          title: 'Excellent Savings — ${rate.toStringAsFixed(0)}%',
          body: 'Saving ${rate.toStringAsFixed(0)}% of income puts you ahead of 90% of people. '
              'Consider investing the surplus for compounding growth.',
        ));
      } else if (rate >= 50) {
        insights.add(Insight(
          type: 'positive', priority: 6, emoji: '🏆',
          title: 'Exceptional! Saving ${rate.toStringAsFixed(0)}%',
          body: 'You\'re saving more than half your income. '
              'If you\'re not already maxing out 80C (₹1.5L), ELSS funds, and NPS — now\'s the time.',
        ));
      }
    }

    // ── 3. Budget alerts (prioritised — over first, then warnings) ───────────
    final overBudgets = budgetStatuses.where((s) => s.isOver).toList()
      ..sort((a, b) => (b.spent - b.budget.limitAmount).compareTo(a.spent - a.budget.limitAmount));
    for (final s in overBudgets.take(2)) {
      insights.add(Insight(
        type: 'warning', priority: 2, emoji: '🚨',
        title: 'Over Budget: ${s.budget.category}',
        body: 'Exceeded by ₹${(s.spent - s.budget.limitAmount).toStringAsFixed(0)} '
            '(${(s.usageRatio * 100).toStringAsFixed(0)}% of ₹${s.budget.limitAmount.toStringAsFixed(0)} limit). '
            '${_daysLeft(now)} days left in the month.',
      ));
    }
    for (final s in budgetStatuses.where((s) => s.isWarning && !s.isOver).take(1)) {
      insights.add(Insight(
        type: 'warning', priority: 3, emoji: '⚡',
        title: 'Budget Warning: ${s.budget.category}',
        body: '${(s.usageRatio * 100).toStringAsFixed(0)}% used — '
            '₹${s.remaining.toStringAsFixed(0)} left for ${_daysLeft(now)} more days '
            '(≈₹${(s.remaining / _daysLeft(now)).toStringAsFixed(0)}/day).',
      ));
    }

    // ── 4. Month-over-month spending change ──────────────────────────────────
    final expByCategory = <String, double>{};
    for (final t in expenses) {
      expByCategory[t.category] = (expByCategory[t.category] ?? 0) + t.amount;
    }
    if (expByCategory.isNotEmpty && totalExpenses > 0) {
      final top = expByCategory.entries.reduce((a, b) => a.value > b.value ? a : b);
      final pct = top.value / totalExpenses * 100;
      if (pct > 45) {
        insights.add(Insight(
          type: 'tip', priority: 4, emoji: '🎯',
          title: '${top.key} dominates spending',
          body: '${pct.toStringAsFixed(0)}% of all expenses (₹${top.value.toStringAsFixed(0)}) '
              'are in ${top.key}. Consider setting a budget to keep this in check.',
        ));
      }
    }

    // ── 5. Spike / anomaly detection ────────────────────────────────────────
    final byCategory = <String, List<double>>{};
    for (final t in expenses) {
      byCategory.putIfAbsent(t.category, () => []).add(t.amount);
    }
    for (final entry in byCategory.entries) {
      if (entry.value.length < 3) continue;
      final avg   = entry.value.fold(0.0, (s, a) => s + a) / entry.value.length;
      final spikes = entry.value.where((a) => a > avg * 2.5).toList();
      if (spikes.isNotEmpty) {
        insights.add(Insight(
          type: 'warning', priority: 3, emoji: '📊',
          title: 'Unusual Spend in ${entry.key}',
          body: '${spikes.length} transaction${spikes.length > 1 ? 's' : ''} '
              'in ${entry.key} were 2.5× above your average of ₹${avg.toStringAsFixed(0)}. '
              'Largest: ₹${spikes.reduce((a, b) => a > b ? a : b).toStringAsFixed(0)}.',
        ));
      }
    }

    // ── 6. Weekend vs weekday spending ───────────────────────────────────────
    if (expenses.length >= 5) {
      double weekdayTotal = 0, weekendTotal = 0;
      int weekdayCount = 0, weekendCount = 0;
      for (final t in expenses) {
        final wd = t.date.weekday;
        if (wd == 6 || wd == 7) { weekendTotal += t.amount; weekendCount++; }
        else { weekdayTotal += t.amount; weekdayCount++; }
      }
      if (weekdayCount > 0 && weekendCount > 0) {
        final wdAvg = weekdayTotal / weekdayCount;
        final weAvg = weekendTotal / weekendCount;
        if (weAvg > wdAvg * 2) {
          insights.add(Insight(
            type: 'tip', priority: 5, emoji: '📅',
            title: 'Weekend Spending is ${(weAvg / wdAvg).toStringAsFixed(1)}× Higher',
            body: 'Average weekend transaction: ₹${weAvg.toStringAsFixed(0)} '
                'vs ₹${wdAvg.toStringAsFixed(0)} on weekdays. '
                'Weekend spending drives ${(weekendTotal / totalExpenses * 100).toStringAsFixed(0)}% of total.',
          ));
        }
      }
    }

    // ── 7. Recurring/subscription detection ─────────────────────────────────
    final amountGroups = <double, int>{};
    for (final t in expenses) {
      final rounded = (t.amount / 10).round() * 10.0;
      amountGroups[rounded] = (amountGroups[rounded] ?? 0) + 1;
    }
    final recurring = amountGroups.entries.where((e) => e.value >= 2 && e.key >= 99).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (recurring.length >= 2) {
      insights.add(Insight(
        type: 'info', priority: 5, emoji: '🔄',
        title: '${recurring.take(3).length} Possible Subscriptions Detected',
        body: 'Amounts like ₹${recurring.first.key.toStringAsFixed(0)} '
            '${recurring.length > 1 ? 'and ₹${recurring[1].key.toStringAsFixed(0)} ' : ''}'
            'appear repeatedly. Review if all subscriptions are still needed.',
      ));
    }

    // ── 8. Investment ratio nudge ────────────────────────────────────────────
    if (totalIncome > 0 && holdings.isNotEmpty) {
      final totalPortfolio = holdings.fold(0.0, (s, h) => s + h.investedAmount);
      final monthlyInvested = expenses
          .where((t) => t.category.toLowerCase().contains('invest'))
          .fold(0.0, (s, t) => s + t.amount);
      if (monthlyInvested == 0 && totalPortfolio > 0) {
        insights.add(Insight(
          type: 'tip', priority: 5, emoji: '📈',
          title: 'No Investments This Month',
          body: 'You have a portfolio worth ₹${_compact(totalPortfolio)} '
              'but haven\'t logged any investments this month. '
              'Consistency is key — even ₹${(totalIncome * 0.1).toStringAsFixed(0)}/mo compounds powerfully.',
        ));
      }
    }

    // ── 9. Portfolio concentration ───────────────────────────────────────────
    if (holdings.isNotEmpty) {
      final totalValue = holdings.fold(0.0, (s, h) => s + h.currentValue);
      for (final h in holdings) {
        if (totalValue > 0 && h.currentValue / totalValue > 0.6) {
          insights.add(Insight(
            type: 'tip', priority: 4, emoji: '⚠️',
            title: 'Heavy Concentration: ${h.name}',
            body: '${(h.currentValue / totalValue * 100).toStringAsFixed(0)}% of your portfolio '
                'is in a single asset. Diversify to reduce risk.',
          ));
          break;
        }
      }
    }

    // ── 10. Daily transaction count (consistency) ────────────────────────────
    if (transactions.length >= 10 && now.day > 10) {
      final txPerDay = transactions.length / now.day;
      if (txPerDay < 0.3) {
        insights.add(Insight(
          type: 'tip', priority: 7, emoji: '📝',
          title: 'Log More Consistently',
          body: 'You\'re averaging ${(txPerDay).toStringAsFixed(1)} transactions/day. '
              'Logging every expense daily gives you the most accurate picture.',
        ));
      }
    }

    // ── 11. No investments nudge ─────────────────────────────────────────────
    if (holdings.isEmpty && totalIncome > 0) {
      insights.add(Insight(
        type: 'tip', priority: 4, emoji: '🌱',
        title: 'Start Your Investment Journey',
        body: 'You\'re earning but not tracking investments. '
            'A monthly SIP of just ₹${(totalIncome * 0.1).toStringAsFixed(0)} '
            'can grow significantly with compounding over time.',
      ));
    }

    // ── 12. No transactions this month ───────────────────────────────────────
    if (transactions.isEmpty) {
      insights.add(const Insight(
        type: 'info', priority: 9, emoji: '➕',
        title: 'Nothing Tracked Yet',
        body: 'Add your first transaction to get personalised insights here.',
      ));
    }

    // Sort by priority and return top 5
    insights.sort((a, b) => a.priority.compareTo(b.priority));
    return insights.take(5).toList();
  }

  static int _daysLeft(DateTime now) =>
      _daysInMonth(now.year, now.month) - now.day;

  static int _daysInMonth(int year, int month) {
    if (month == 12) return DateTime(year + 1, 1, 1).subtract(const Duration(days: 1)).day;
    return DateTime(year, month + 1, 1).subtract(const Duration(days: 1)).day;
  }

  static String _compact(double v) {
    if (v >= 1e7) return '₹${(v / 1e7).toStringAsFixed(1)}Cr';
    if (v >= 1e5) return '₹${(v / 1e5).toStringAsFixed(1)}L';
    if (v >= 1e3) return '₹${(v / 1e3).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }
}
