import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/database/database_helper.dart';
import '../../core/services/export_service.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/portfolio_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Settings', style: GoogleFonts.inter(color: AppColors.text1, fontSize: 22, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // App info card
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.15), AppColors.surface], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Text('🐿️', style: TextStyle(fontSize: 40)),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('FinanceOS', style: GoogleFonts.inter(color: AppColors.text1, fontSize: 20, fontWeight: FontWeight.w800)),
                Text('Personal Finance Tracker', style: GoogleFonts.inter(color: AppColors.text2, fontSize: 13)),
                const SizedBox(height: 4),
                Text('v1.0.0', style: GoogleFonts.inter(color: AppColors.text3, fontSize: 12)),
              ]),
            ]),
          ),

          _SectionHeader('Data Management'),
          _SettingsTile(
            icon: Icons.download_rounded,
            iconColor: AppColors.income,
            title: 'Export Transactions (CSV)',
            subtitle: 'Share a spreadsheet of all transactions',
            onTap: () async {
              try {
                await ExportService.exportTransactionsCSV();
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
              }
            },
          ),
          _SettingsTile(
            icon: Icons.backup_rounded,
            iconColor: AppColors.primary,
            title: 'Export Full Backup (JSON)',
            subtitle: 'All data — transactions, budgets, holdings',
            onTap: () async {
              try {
                await ExportService.exportAllDataJSON();
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
              }
            },
          ),
          _SettingsTile(
            icon: Icons.delete_forever_rounded,
            iconColor: AppColors.expense,
            title: 'Clear All Data',
            subtitle: 'Permanently delete all transactions and settings',
            onTap: () => _confirmClearAll(context),
          ),

          const SizedBox(height: 20),
          _SectionHeader('About'),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            iconColor: AppColors.info,
            title: 'Version',
            subtitle: '1.0.0 — Personal Finance OS',
            onTap: null,
          ),
          _SettingsTile(
            icon: Icons.storage_rounded,
            iconColor: AppColors.text2,
            title: 'Storage',
            subtitle: 'All data stored locally on this device',
            onTap: null,
          ),
          _SettingsTile(
            icon: Icons.lock_outline_rounded,
            iconColor: AppColors.text2,
            title: 'Privacy',
            subtitle: 'No data sent to any external server',
            onTap: null,
          ),

          const SizedBox(height: 32),
          Center(
            child: Text(
              'Made with ❤️ — Personal Project',
              style: GoogleFonts.inter(color: AppColors.text3, fontSize: 12),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface2,
        title: Text('Clear All Data?', style: GoogleFonts.inter(color: AppColors.text1, fontWeight: FontWeight.w700)),
        content: Text(
          'This will permanently delete ALL transactions, budgets, holdings, and reminders. This cannot be undone.',
          style: GoogleFonts.inter(color: AppColors.text2, fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete Everything', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await DatabaseHelper.instance.clearAllData();
      await context.read<TransactionProvider>().loadTransactions();
      await context.read<BudgetProvider>().loadBudgets();
      await context.read<PortfolioProvider>().loadHoldings();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data cleared'), backgroundColor: AppColors.expense),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(title, style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
  );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingsTile({required this.icon, required this.iconColor, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: iconColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: GoogleFonts.inter(color: AppColors.text1, fontSize: 14, fontWeight: FontWeight.w600)),
                Text(subtitle, style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12)),
              ])),
              if (onTap != null) const Icon(Icons.chevron_right, color: AppColors.text3, size: 18),
            ]),
          ),
        ),
      ),
    );
  }
}
