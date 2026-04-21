import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'providers/transaction_provider.dart';
import 'providers/budget_provider.dart';
import 'providers/portfolio_provider.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/transactions/transactions_screen.dart';
import 'screens/budget/budget_screen.dart';
import 'screens/portfolio/portfolio_screen.dart';
import 'screens/analytics/analytics_screen.dart';
import 'screens/settings/settings_screen.dart';
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
      ],
      child: MaterialApp(
        title: 'FinanceOS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
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

  final _screens = const [
    DashboardScreen(),
    TransactionsScreen(),
    BudgetScreen(),
    PortfolioScreen(),
    AnalyticsScreen(),
  ];

  final _navItems = const [
    BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home_rounded), label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long_rounded), label: 'Transactions'),
    BottomNavigationBarItem(icon: Icon(Icons.track_changes_outlined), activeIcon: Icon(Icons.track_changes_rounded), label: 'Budgets'),
    BottomNavigationBarItem(icon: Icon(Icons.show_chart_outlined), activeIcon: Icon(Icons.show_chart_rounded), label: 'Portfolio'),
    BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart_rounded), label: 'Analytics'),
  ];

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(index: _currentIndex, children: _screens),
        floatingActionButton: _currentIndex != 3
            ? FloatingActionButton(
                onPressed: () => AddTransactionSheet.show(context),
                backgroundColor: AppColors.primary,
                elevation: 6,
                child: const Icon(Icons.add, color: Colors.white, size: 28),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: _BottomBar(
          currentIndex: _currentIndex,
          items: _navItems,
          onTap: (i) => setState(() => _currentIndex = i),
          showFab: _currentIndex != 3,
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int currentIndex;
  final List<BottomNavigationBarItem> items;
  final ValueChanged<int> onTap;
  final bool showFab;

  const _BottomBar({required this.currentIndex, required this.items, required this.onTap, required this.showFab});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;

              // Center gap for FAB when not on portfolio
              if (showFab && i == 2) {
                return Expanded(
                  child: Row(children: [
                    _NavItem(index: i, item: items[i], currentIndex: currentIndex, onTap: onTap),
                    const Expanded(child: SizedBox(width: 56)), // FAB space
                    _NavItem(index: i + 1, item: items[i + 1], currentIndex: currentIndex, onTap: onTap),
                  ]),
                );
              }
              if (showFab && i == 3) return const SizedBox.shrink();

              return _NavItem(index: i, item: item, currentIndex: currentIndex, onTap: onTap);
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final BottomNavigationBarItem item;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NavItem({required this.index, required this.item, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final selected = currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: selected
                ? IconTheme(data: const IconThemeData(color: AppColors.primary), child: item.activeIcon as Widget)
                : IconTheme(data: const IconThemeData(color: AppColors.text3), child: item.icon as Widget),
          ),
          const SizedBox(height: 2),
          Text(
            item.label ?? '',
            style: GoogleFonts.inter(
              color: selected ? AppColors.primary : AppColors.text3,
              fontSize: 10,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ]),
      ),
    );
  }
}
