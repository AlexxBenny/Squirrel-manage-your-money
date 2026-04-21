import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'providers/transaction_provider.dart';
import 'providers/budget_provider.dart';
import 'providers/portfolio_provider.dart';
import 'providers/tag_provider.dart';
import 'providers/category_provider.dart';
import 'providers/goal_provider.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/transactions/transactions_screen.dart';
import 'screens/budget/budget_screen.dart';
import 'screens/portfolio/portfolio_screen.dart';
import 'screens/analytics/analytics_screen.dart';
import 'screens/goals/goals_screen.dart';
import 'screens/transactions/add_transaction_sheet.dart';

class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => BudgetProvider()),
        ChangeNotifierProvider(create: (_) => PortfolioProvider()),
        ChangeNotifierProvider(create: (_) => TagProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => GoalProvider()),
      ],
      child: MaterialApp(
        title: 'Squirrel',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const _AppShell(),
      ),
    );
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell();
  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  int _currentIndex = 0;

  // FAB only on Home + Txns — all other tabs have their own actions or none
  static const _noFabIndices = {2, 3, 4, 5};

  final _screens = const [
    DashboardScreen(),
    TransactionsScreen(),
    BudgetScreen(),
    PortfolioScreen(),
    GoalsScreen(),
    AnalyticsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final showFab = !_noFabIndices.contains(_currentIndex);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(index: _currentIndex, children: _screens),
        floatingActionButton: AnimatedScale(
          scale: showFab ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 220),
          curve: showFab ? Curves.easeOutBack : Curves.easeIn,
          child: FloatingActionButton(
            onPressed: showFab ? () => AddTransactionSheet.show(context) : null,
            backgroundColor: AppColors.primary,
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: _BottomBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
        ),
      ),
    );
  }
}

// ── Bottom navigation bar ─────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomBar({required this.currentIndex, required this.onTap});

  static const _items = [
    _NavDef(icon: Icons.home_outlined,        activeIcon: Icons.home_rounded,         label: 'Home'),
    _NavDef(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded,  label: 'Txns'),
    _NavDef(icon: Icons.track_changes_outlined,activeIcon: Icons.track_changes_rounded, label: 'Budget'),
    _NavDef(icon: Icons.show_chart_outlined,   activeIcon: Icons.show_chart_rounded,    label: 'Portfolio'),
    _NavDef(icon: Icons.flag_outlined,         activeIcon: Icons.flag_rounded,          label: 'Goals'),
    _NavDef(icon: Icons.bar_chart_outlined,    activeIcon: Icons.bar_chart_rounded,     label: 'Analytics'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(children: [
            Expanded(child: _NavTile(index: 0, def: _items[0], currentIndex: currentIndex, onTap: onTap)),
            Expanded(child: _NavTile(index: 1, def: _items[1], currentIndex: currentIndex, onTap: onTap)),
            Expanded(child: _NavTile(index: 2, def: _items[2], currentIndex: currentIndex, onTap: onTap)),
            Expanded(child: _NavTile(index: 3, def: _items[3], currentIndex: currentIndex, onTap: onTap)),
            Expanded(child: _NavTile(index: 4, def: _items[4], currentIndex: currentIndex, onTap: onTap)),
            Expanded(child: _NavTile(index: 5, def: _items[5], currentIndex: currentIndex, onTap: onTap)),
          ]),
        ),
      ),
    );
  }
}

class _NavDef {
  final IconData icon, activeIcon;
  final String label;
  const _NavDef({required this.icon, required this.activeIcon, required this.label});
}

class _NavTile extends StatelessWidget {
  final int index, currentIndex;
  final _NavDef def;
  final ValueChanged<int> onTap;
  const _NavTile({required this.index, required this.currentIndex, required this.def, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final selected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySurface : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(selected ? def.activeIcon : def.icon,
            color: selected ? AppColors.primary : AppColors.text3, size: 22),
        ),
        const SizedBox(height: 2),
        Text(def.label, style: GoogleFonts.inter(
          color: selected ? AppColors.primary : AppColors.text3,
          fontSize: 9,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        )),
      ]),
    );
  }
}
