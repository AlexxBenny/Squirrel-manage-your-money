import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/categories.dart';
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
    final cat = Categories.findById(status.budget.category);
    final color = status.isOver
        ? AppColors.expense
        : status.isWarning
            ? AppColors.warning
            : AppColors.income;
    final emoji = cat?.emoji ?? '💰';
    final ratio = (status.usageRatio).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status.isOver ? AppColors.expense.withOpacity(0.4) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat?.name ?? status.budget.category,
                      style: GoogleFonts.inter(
                        color: AppColors.text1,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      status.budget.period == 'monthly' ? 'Monthly limit' : 'Weekly limit',
                      style: GoogleFonts.inter(color: AppColors.text3, fontSize: 11),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') onEdit?.call();
                  if (v == 'delete') onDelete?.call();
                },
                color: AppColors.surface2,
                icon: const Icon(Icons.more_vert, color: AppColors.text3, size: 18),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit', style: GoogleFonts.inter(color: AppColors.text1)),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: GoogleFonts.inter(color: AppColors.expense)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: AppColors.surface3,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${CurrencyFormatter.format(status.spent)} spent',
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                status.isOver
                    ? '${CurrencyFormatter.format(status.spent - status.budget.limitAmount)} over'
                    : '${CurrencyFormatter.format(status.remaining)} left',
                style: GoogleFonts.inter(
                  color: status.isOver ? AppColors.expense : AppColors.text2,
                  fontSize: 12,
                ),
              ),
              Text(
                'of ${CurrencyFormatter.format(status.budget.limitAmount)}',
                style: GoogleFonts.inter(color: AppColors.text3, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
