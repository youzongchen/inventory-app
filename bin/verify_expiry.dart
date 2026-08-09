import 'dart:io';
import '../lib/models.dart';
import '../lib/services/excel_repo.dart';

void main() {
  const src = r'D:\User\Desktop\TASK\庫存管理.xlsx';
  final data = ExcelRepo.load(src);
  print('load ok - products: ${data.products.length}, tx: ${data.transactions.length}');

  final tx = List<TxRecord>.from(data.transactions);
  final nextId = tx.map((t) => t.id).reduce((a, b) => a > b ? a : b) + 1;
  tx.add(TxRecord(
    id: nextId,
    barcode: '9421905520270',
    name: 'Noopi4',
    location: '家裡',
    dateTime: DateTime.now(),
    type: '入',
    expiryDate: DateTime(2027, 3, 15),
    note: '測試效期',
  ));

  const tmp = r'C:\Users\user\dev\inventory_app\bin\expiry_roundtrip.xlsx';
  ExcelRepo.save(tmp, data.products, tx);
  print('save ok');

  final reloaded = ExcelRepo.load(tmp);
  final t = reloaded.transactions.firstWhere((t) => t.id == nextId);
  print('reloaded expiry: ${t.expiryDate}, note: ${t.note}');

  final overview = ExcelRepo.computeOverview(reloaded.products, reloaded.transactions);
  final row = overview.firstWhere((r) => r.barcode == '9421905520270' && r.location == '家裡');
  print('overview nearestExpiry: ${row.nearestExpiry}');

  File(tmp).deleteSync();
}
