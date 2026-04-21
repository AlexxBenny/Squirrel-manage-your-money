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
      version: 1,
      onCreate: _onCreate,
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
        ticker TEXT NOT NULL,
        asset_class TEXT NOT NULL,
        quantity REAL NOT NULL,
        avg_buy_price REAL NOT NULL,
        currency TEXT DEFAULT 'INR',
        exchange TEXT,
        notes TEXT,
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

    // Indexes for performance
    await db.execute('CREATE INDEX idx_tx_date ON transactions(date)');
    await db.execute('CREATE INDEX idx_tx_category ON transactions(category)');
    await db.execute('CREATE INDEX idx_tx_type ON transactions(type)');
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
  }
}
