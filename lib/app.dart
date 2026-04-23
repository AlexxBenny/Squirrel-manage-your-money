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
import 'providers/lend_provider.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/transactions/transactions_screen.dart';
import 'screens/budget/budget_screen.dart';
import 'screens/portfolio/portfolio_screen.dart';
import 'screens/analytics/analytics_screen.dart';
import 'screens/goals/goals_screen.dart';
import 'screens/lendings/lend_screen.dart';
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
        ChangeNotifierProvider(create: (_) => LendProvider()),
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

class _AppShellState extends State<_AppShell> with WidgetsBindingObserver {
  int _currentIndex = 0;

  // FAB only on Home + Txns — all other tabs have their own actions or none
  static const _noFabIndices = {2, 3, 4, 5, 6};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Called by Flutter whenever the app lifecycle changes.
  /// On resume, silently refresh prices if the 8-hour interval has elapsed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<PortfolioProvider>().refreshIfStale();
    }
  }

  final _screens = const [
    DashboardScreen(),
    TransactionsScreen(),
    BudgetScreen(),
    PortfolioScreen(),
    GoalsScreen(),
    AnalyticsScreen(),
    LendScreen(),
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
        body: _LazyIndexedStack(index: _currentIndex, children: _screens),
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
    _NavDef(icon: Icons.handshake_outlined,    activeIcon: Icons.handshake_rounded,     label: 'Lendings'),
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
            Expanded(child: _NavTile(index: 6, def: _items[6], currentIndex: currentIndex, onTap: onTap)),
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

// ── Lazy indexed stack ────────────────────────────────────────────────────────
/// Builds each child only on its first visit, then keeps it alive using
/// Offstage so state is preserved without eagerly constructing all screens.
class _LazyIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  const _LazyIndexedStack({required this.index, required this.children});
  @override
  State<_LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<_LazyIndexedStack> {
  // Tracks which tab indices have ever been shown
  late final Set<int> _activated;

  @override
  void initState() {
    super.initState();
    _activated = {widget.index}; // only the initial tab is built at startup
  }

  @override
  void didUpdateWidget(_LazyIndexedStack old) {
    super.didUpdateWidget(old);
    _activated.add(widget.index); // mark new tab as built on first visit
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: List.generate(widget.children.length, (i) {
        if (!_activated.contains(i)) return const SizedBox.shrink();
        return Offstage(
          offstage: i != widget.index,
          child: TickerMode(
            enabled: i == widget.index,
            child: widget.children[i],
          ),
        );
      }),
    );
  }
}
