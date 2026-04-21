import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/database/database_helper.dart';
import '../../models/transaction_model.dart';

class ExportService {
  static Future<void> exportTransactionsCSV() async {
    final maps = await DatabaseHelper.instance.getAllTransactionsRaw();
    final transactions = maps.map(TransactionModel.fromMap).toList();

    final buffer = StringBuffer();
    buffer.writeln('Date,Type,Category,Amount,Note,Tags');
    for (final t in transactions) {
      buffer.writeln(
        '"${t.date.toIso8601String()}",'
        '"${t.type}",'
        '"${t.category}",'
        '${t.amount},'
        '"${t.note ?? ''}",'
        '"${t.tags ?? ''}"',
      );
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/finance_export_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(buffer.toString());

    await Share.shareXFiles([XFile(file.path)], text: 'FinanceOS Transaction Export');
  }

  static Future<void> exportAllDataJSON() async {
    final maps = await DatabaseHelper.instance.getAllTransactionsRaw();
    final exportData = {
      'exported_at': DateTime.now().toIso8601String(),
      'version': '1.0',
      'transactions': maps,
    };

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/finance_backup_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(json.encode(exportData));

    await Share.shareXFiles([XFile(file.path)], text: 'FinanceOS Full Backup');
  }

  static Future<int> importFromJSON(String filePath) async {
    final file = File(filePath);
    final content = await file.readAsString();
    final data = json.decode(content) as Map<String, dynamic>;
    final transactions = (data['transactions'] as List<dynamic>?) ?? [];

    int count = 0;
    for (final tx in transactions) {
      try {
        await DatabaseHelper.instance.insertTransaction(tx as Map<String, dynamic>);
        count++;
      } catch (_) {}
    }
    return count;
  }
}
