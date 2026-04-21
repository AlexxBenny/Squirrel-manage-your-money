import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/database/database_helper.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/export_service.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/portfolio_provider.dart';
import '../../widgets/wave_widgets.dart';
import '../tags/manage_tags_sheet.dart';
import '../categories/manage_categories_sheet.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: ClipPath(
          clipper: WaveClipper(),
          child: Container(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 56),
            decoration: const BoxDecoration(gradient: AppColors.headerGradient),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('🐿️', style: TextStyle(fontSize: 36)),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('FinanceOS', style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  Text('Personal Finance Tracker', style: GoogleFonts.inter(color: Colors.white60, fontSize: 13)),
                ]),
              ]),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.25))),
                child: Row(children: [
                  const Icon(Icons.verified_rounded, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Text('v1.0.0 · Offline-first · Private', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                ]),
              ),
            ]),
          ),
        )),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          sliver: SliverList(delegate: SliverChildListDelegate([
            _header('Tags & Organization'),
            _tile(context,
              icon: Icons.label_rounded, color: AppColors.primary,
              title: 'Manage Custom Tags',
              subtitle: 'Create tags like "Himalayas" or "Road Trip"',
              onTap: () => ManageTagsSheet.show(context),
            ),
            _tile(context,
              icon: Icons.category_rounded, color: AppColors.info,
              title: 'Manage Custom Categories',
              subtitle: 'Create your own expense & income categories',
              onTap: () => ManageCategoriesSheet.show(context),
            ),
            const SizedBox(height: 20),
            _header('Data Management'),
            _tile(context,
              icon: Icons.download_rounded, color: AppColors.income,
              title: 'Export Transactions (CSV)',
              subtitle: 'Share a spreadsheet of all transactions',
              onTap: () async {
                try { await ExportService.exportTransactionsCSV(); }
                catch (e) { if (context.mounted) _snack(context, 'Export failed: $e'); }
              },
            ),
            _tile(context,
              icon: Icons.backup_rounded, color: AppColors.primary,
              title: 'Export Full Backup (JSON)',
              subtitle: 'All data — transactions, budgets, holdings',
              onTap: () async {
                try { await ExportService.exportAllDataJSON(); }
                catch (e) { if (context.mounted) _snack(context, 'Backup failed: $e'); }
              },
            ),
            _tile(context,
              icon: Icons.delete_forever_rounded, color: AppColors.expense,
              title: 'Clear All Data',
              subtitle: 'Protected by biometrics or PIN',
              onTap: () => _confirmClear(context),
            ),
            const SizedBox(height: 20),
            _header('About'),
            _tile(context, icon: Icons.info_outline_rounded, color: AppColors.info, title: 'Version', subtitle: '1.0.0 — FinanceOS', onTap: null),
            _tile(context, icon: Icons.storage_rounded, color: AppColors.text3, title: 'Storage', subtitle: 'All data stored locally on this device', onTap: null),
            _tile(context, icon: Icons.lock_outline_rounded, color: AppColors.text3, title: 'Privacy', subtitle: 'No data sent to any external server', onTap: null),
            const SizedBox(height: 32),
            Center(child: Text('Made with ❤️ — Personal Project', style: GoogleFonts.inter(color: AppColors.text3, fontSize: 12))),
          ])),
        ),
      ]),
    );
  }

  Widget _header(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 8),
    child: Text(title.toUpperCase(), style: GoogleFonts.inter(color: AppColors.text3, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
  );

  Widget _tile(BuildContext context, {required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: GoogleFonts.inter(color: AppColors.text1, fontSize: 14, fontWeight: FontWeight.w600)),
                Text(subtitle, style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12)),
              ])),
              if (onTap != null) const Icon(Icons.chevron_right_rounded, color: AppColors.text3, size: 18),
            ]),
          ),
        ),
      ),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _confirmClear(BuildContext context) async {
    // Step 1: Authenticate (biometric → device PIN → app PIN)
    final authed = await AuthService.authenticate(
      context,
      reason: 'Confirm your identity to clear all financial data',
    );
    if (!authed || !context.mounted) return;

    // Step 2: Final confirmation dialog
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: AppColors.expense, size: 22),
        const SizedBox(width: 10),
        Text('Clear All Data?', style: GoogleFonts.inter(color: AppColors.text1, fontWeight: FontWeight.w700)),
      ]),
      content: Text(
        'This will permanently delete ALL transactions, budgets, and holdings. Cannot be undone.',
        style: GoogleFonts.inter(color: AppColors.text2, fontSize: 14)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense, foregroundColor: Colors.white, minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('Delete All', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        ),
      ],
    ));

    if (ok == true && context.mounted) {
      await DatabaseHelper.instance.clearAllData();
      await context.read<TransactionProvider>().loadTransactions();
      await context.read<BudgetProvider>().loadBudgets();
      await context.read<PortfolioProvider>().loadHoldings();
      if (context.mounted) _snack(context, '✓ All data cleared');
    }
  }
}
