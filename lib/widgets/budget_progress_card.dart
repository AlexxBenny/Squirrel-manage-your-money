import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../models/budget_model.dart';

class BudgetProgressCard extends StatelessWidget {
  final BudgetStatus status;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const BudgetProgressCard({
    super.key,
    required this.status,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final budget = status.budget;
    final ratio = status.usageRatio.clamp(0.0, 1.0);

    final Color trackColor;
    final Color progressColor;
    final Color chipColor;
    final String chipLabel;

    if (status.isOver) {
      trackColor = AppColors.expense.withValues(alpha: 0.1);
      progressColor = AppColors.expense;
      chipColor = AppColors.expense;
      chipLabel = 'Over budget';
    } else if (status.isWarning) {
      trackColor = AppColors.warning.withValues(alpha: 0.1);
      progressColor = AppColors.warning;
      chipColor = AppColors.warning;
      chipLabel = '${(ratio * 100).toStringAsFixed(0)}% used';
    } else {
      trackColor = AppColors.income.withValues(alpha: 0.08);
      progressColor = AppColors.income;
      chipColor = AppColors.income;
      chipLabel = 'On track';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Category icon
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.category_rounded, color: progressColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _capitalize(budget.category),
                      style: GoogleFonts.inter(
                        color: AppColors.text1,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${_capitalize(budget.period)} limit',
                      style: GoogleFonts.inter(color: AppColors.text3, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Status chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: chipColor.withValues(alpha: 0.3)),
                ),
                child: Text(chipLabel,
                  style: GoogleFonts.inter(color: chipColor, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') onEdit?.call();
                  if (v == 'delete') onDelete?.call();
                },
                color: AppColors.surface,
                icon: Icon(Icons.more_vert, color: AppColors.text3, size: 18),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text('Edit', style: GoogleFonts.inter(color: AppColors.text1))),
                  PopupMenuItem(value: 'delete', child: Text('Delete', style: GoogleFonts.inter(color: AppColors.expense))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Amount row
          Row(
            children: [
              Text(
                CurrencyFormatter.format(status.spent),
                style: GoogleFonts.inter(
                  color: progressColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                ' / ${CurrencyFormatter.format(budget.limitAmount)}',
                style: GoogleFonts.inter(color: AppColors.text3, fontSize: 14),
              ),
              const Spacer(),
              Text(
                '${CurrencyFormatter.format(status.remaining)} left',
                style: GoogleFonts.inter(
                  color: status.isOver ? AppColors.expense : AppColors.text2,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: trackColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ratio,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [progressColor.withValues(alpha: 0.8), progressColor],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
