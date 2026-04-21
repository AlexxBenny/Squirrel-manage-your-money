import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'finance_os.db');
    return await openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        currency TEXT DEFAULT 'INR',
        category TEXT NOT NULL,
        note TEXT,
        date TEXT NOT NULL,
        tags TEXT,
        is_recurring INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE budgets (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL UNIQUE,
        limit_amount REAL NOT NULL,
        period TEXT NOT NULL DEFAULT 'monthly',
        alert_at REAL NOT NULL DEFAULT 0.8
      )
    ''');

    await db.execute('''
      CREATE TABLE holdings (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        ticker TEXT,
        asset_class TEXT NOT NULL,
        invested_amount REAL NOT NULL DEFAULT 0,
        current_value_override REAL,
        quantity REAL,
        avg_buy_price REAL,
        exchange TEXT,
        sip_day INTEGER,
        maturity_date TEXT,
        alert_enabled INTEGER NOT NULL DEFAULT 1,
        meta TEXT,
        notes TEXT,
        currency TEXT DEFAULT 'INR',
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE reminders (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        due_date TEXT NOT NULL,
        repeat TEXT DEFAULT 'none',
        is_done INTEGER DEFAULT 0,
        category TEXT DEFAULT 'custom',
        amount REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE price_cache (
        ticker TEXT PRIMARY KEY,
        price REAL NOT NULL,
        change_pct REAL,
        fetched_at TEXT NOT NULL
      )
    ''');

    // Custom tags table
    await db.execute('''
      CREATE TABLE custom_tags (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        emoji TEXT NOT NULL DEFAULT '🏷️',
        color_value INTEGER NOT NULL DEFAULT 2521573,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE custom_categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        emoji TEXT NOT NULL DEFAULT '💸',
        color_value INTEGER NOT NULL DEFAULT 9147561,
        is_income INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE goals (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        emoji TEXT NOT NULL DEFAULT '🎯',
        category TEXT NOT NULL DEFAULT 'other',
        target_amount REAL NOT NULL,
        current_amount REAL NOT NULL DEFAULT 0,
        target_date TEXT,
        linked_holding_ids TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Indexes for performance
    await db.execute('CREATE INDEX idx_tx_date ON transactions(date)');
    await db.execute('CREATE INDEX idx_tx_category ON transactions(category)');
    await db.execute('CREATE INDEX idx_tx_type ON transactions(type)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS custom_tags (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          emoji TEXT NOT NULL DEFAULT '🏷️',
          color_value INTEGER NOT NULL DEFAULT 2521573,
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS custom_categories (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          emoji TEXT NOT NULL DEFAULT '💸',
          color_value INTEGER NOT NULL DEFAULT 9147561,
          is_income INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 4) {
      // Add rich portfolio fields to holdings
      try { await db.execute('ALTER TABLE holdings ADD COLUMN invested_amount REAL NOT NULL DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE holdings ADD COLUMN current_value_override REAL'); } catch (_) {}
      try { await db.execute('ALTER TABLE holdings ADD COLUMN sip_day INTEGER'); } catch (_) {}
      try { await db.execute('ALTER TABLE holdings ADD COLUMN maturity_date TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE holdings ADD COLUMN alert_enabled INTEGER NOT NULL DEFAULT 1'); } catch (_) {}
      try { await db.execute('ALTER TABLE holdings ADD COLUMN meta TEXT'); } catch (_) {}
      // ticker and quantity now nullable for FD/RE/Other
      try { await db.execute("UPDATE holdings SET invested_amount = COALESCE(quantity,0) * COALESCE(avg_buy_price,0) WHERE invested_amount = 0"); } catch (_) {}
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS goals (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          emoji TEXT NOT NULL DEFAULT '🎯',
          category TEXT NOT NULL DEFAULT 'other',
          target_amount REAL NOT NULL,
          current_amount REAL NOT NULL DEFAULT 0,
          target_date TEXT,
          linked_holding_ids TEXT,
          notes TEXT,
          created_at TEXT NOT NULL
        )
      ''');
    }
  }

  // ─── Transactions ─────────────────────────────────────────────────────────

  Future<int> insertTransaction(Map<String, dynamic> tx) async {
    final db = await database;
    return await db.insert('transactions', tx, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getTransactions({
    String? type,
    String? category,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (type != null) { conditions.add('type = ?'); args.add(type); }
    if (category != null) { conditions.add('category = ?'); args.add(category); }
    if (from != null) { conditions.add('date >= ?'); args.add(from.toIso8601String()); }
    if (to != null) { conditions.add('date <= ?'); args.add(to.toIso8601String()); }

    final where = conditions.isEmpty ? null : conditions.join(' AND ');
    return await db.query(
      'transactions',
      where: where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'date DESC',
      limit: limit,
    );
  }

  Future<int> updateTransaction(Map<String, dynamic> tx) async {
    final db = await database;
    return await db.update('transactions', tx, where: 'id = ?', whereArgs: [tx['id']]);
  }

  Future<int> deleteTransaction(String id) async {
    final db = await database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, double>> getCategoryTotals({required String type, DateTime? from, DateTime? to}) async {
    final db = await database;
    final conditions = ['type = ?'];
    final args = <dynamic>[type];

    if (from != null) { conditions.add('date >= ?'); args.add(from.toIso8601String()); }
    if (to != null) { conditions.add('date <= ?'); args.add(to.toIso8601String()); }

    final results = await db.rawQuery(
      'SELECT category, SUM(amount) as total FROM transactions WHERE ${conditions.join(' AND ')} GROUP BY category',
      args,
    );
    return {for (var r in results) r['category'] as String: (r['total'] as num).toDouble()};
  }

  Future<double> getTotalByType({required String type, DateTime? from, DateTime? to}) async {
    final db = await database;
    final conditions = ['type = ?'];
    final args = <dynamic>[type];
    if (from != null) { conditions.add('date >= ?'); args.add(from.toIso8601String()); }
    if (to != null) { conditions.add('date <= ?'); args.add(to.toIso8601String()); }

    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM transactions WHERE ${conditions.join(' AND ')}',
      args,
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// FIX #8: Single grouped query replacing 24 sequential getTotalByType calls.
  /// Returns map of 'YYYY-MM' -> {'income': x, 'expense': y}.
  Future<Map<String, Map<String, double>>> getMonthlyTotals(
      {required DateTime from}) async {
    final db = await database;
    final results = await db.rawQuery(
      '''
      SELECT strftime('%Y-%m', date) AS month, type, SUM(amount) AS total
      FROM transactions
      WHERE date >= ? AND type IN ('income', 'expense')
      GROUP BY month, type
      ''',
      [from.toIso8601String()],
    );
    final map = <String, Map<String, double>>{};
    for (final row in results) {
      final month = row['month'] as String;
      final type  = row['type']  as String;
      final total = (row['total'] as num).toDouble();
      map.putIfAbsent(month, () => {})[type] = total;
    }
    return map;
  }

  // ─── Budgets ──────────────────────────────────────────────────────────────

  Future<int> upsertBudget(Map<String, dynamic> budget) async {
    final db = await database;
    return await db.insert('budgets', budget, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getBudgets() async {
    final db = await database;
    return await db.query('budgets', orderBy: 'category ASC');
  }

  Future<int> deleteBudget(String id) async {
    final db = await database;
    return await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Holdings ─────────────────────────────────────────────────────────────

  Future<int> insertHolding(Map<String, dynamic> holding) async {
    final db = await database;
    return await db.insert('holdings', holding, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getHoldings() async {
    final db = await database;
    return await db.query('holdings', orderBy: 'name ASC');
  }

  Future<int> updateHolding(Map<String, dynamic> holding) async {
    final db = await database;
    return await db.update('holdings', holding, where: 'id = ?', whereArgs: [holding['id']]);
  }

  Future<int> deleteHolding(String id) async {
    final db = await database;
    return await db.delete('holdings', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Reminders ────────────────────────────────────────────────────────────

  Future<int> upsertReminder(Map<String, dynamic> reminder) async {
    final db = await database;
    return await db.insert('reminders', reminder, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getReminders() async {
    final db = await database;
    return await db.query('reminders', orderBy: 'due_date ASC');
  }

  Future<int> deleteReminder(String id) async {
    final db = await database;
    return await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Price Cache ──────────────────────────────────────────────────────────

  Future<void> upsertPrice(String ticker, double price, double? changePct) async {
    final db = await database;
    await db.insert('price_cache', {
      'ticker': ticker,
      'price': price,
      'change_pct': changePct,
      'fetched_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getCachedPrice(String ticker) async {
    final db = await database;
    final results = await db.query('price_cache', where: 'ticker = ?', whereArgs: [ticker]);
    return results.isEmpty ? null : results.first;
  }

  /// FIX #5: Batch-read all cached prices in a single query instead of one
  /// query per holding (was an N+1 problem).
  Future<Map<String, Map<String, dynamic>>> getCachedPrices(
      List<String> tickers) async {
    if (tickers.isEmpty) return {};
    final db = await database;
    final placeholders = List.filled(tickers.length, '?').join(',');
    final results = await db.rawQuery(
      'SELECT * FROM price_cache WHERE ticker IN ($placeholders)',
      tickers,
    );
    return {for (final r in results) r['ticker'] as String: Map<String, dynamic>.from(r)};
  }

  // ─── Custom Tags ──────────────────────────────────────────────────────────

  Future<int> insertTag(Map<String, dynamic> tag) async {
    final db = await database;
    return await db.insert('custom_tags', tag, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getTags() async {
    final db = await database;
    return await db.query('custom_tags', orderBy: 'created_at ASC');
  }

  Future<int> deleteTag(String id) async {
    final db = await database;
    return await db.delete('custom_tags', where: 'id = ?', whereArgs: [id]);
  }

  /// Returns total spent (expenses) grouped by tag ID.
  /// Note: A transaction can appear in multiple tags without double-counting
  /// category totals — tags are an independent organizational dimension.
  Future<Map<String, double>> getTagTotals({DateTime? from, DateTime? to}) async {
    final db = await database;
    final conditions = ['type = ?', "tags IS NOT NULL", "tags != ''"];
    final args = <dynamic>['expense'];
    if (from != null) { conditions.add('date >= ?'); args.add(from.toIso8601String()); }
    if (to != null)   { conditions.add('date <= ?'); args.add(to.toIso8601String()); }

    final rows = await db.query(
      'transactions',
      columns: ['tags', 'amount'],
      where: conditions.join(' AND '),
      whereArgs: args,
    );

    final totals = <String, double>{};
    for (final row in rows) {
      final tagStr = row['tags'] as String;
      final amount = (row['amount'] as num).toDouble();
      for (final tagId in tagStr.split(',').map((s) => s.trim())) {
        if (tagId.isNotEmpty) {
          totals[tagId] = (totals[tagId] ?? 0) + amount;
        }
      }
    }
    return totals;
  }

  // ─── Custom Categories ─────────────────────────────────────────────────────

  Future<int> insertCategory(Map<String, dynamic> cat) async {
    final db = await database;
    return await db.insert('custom_categories', cat, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getCustomCategories() async {
    final db = await database;
    return await db.query('custom_categories', orderBy: 'created_at ASC');
  }

  Future<int> deleteCategory(String id) async {
    final db = await database;
    return await db.delete('custom_categories', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Export ───────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllTransactionsRaw() async {
    final db = await database;
    return await db.query('transactions', orderBy: 'date DESC');
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('transactions');
    await db.delete('budgets');
    await db.delete('holdings');
    await db.delete('reminders');
    await db.delete('price_cache');
    await db.delete('custom_tags');
    await db.delete('custom_categories');
    await db.delete('goals');
  }

  // ─── Goals ────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getGoals() async {
    final db = await database;
    return await db.query('goals', orderBy: 'created_at DESC');
  }

  Future<void> insertGoal(Map<String, dynamic> goal) async {
    final db = await database;
    await db.insert('goals', goal, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateGoal(Map<String, dynamic> goal) async {
    final db = await database;
    await db.update('goals', goal, where: 'id = ?', whereArgs: [goal['id']]);
  }

  Future<void> deleteGoal(String id) async {
    final db = await database;
    await db.delete('goals', where: 'id = ?', whereArgs: [id]);
  }
}
