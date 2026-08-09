import 'dart:io';
import '../lib/services/excel_repo.dart';

void main() {
  const src = r'D:\User\Desktop\TASK\庫存管理.xlsx';
  try {
    final data = ExcelRepo.load(src);
    print('load ok - products: ${data.products.length}, tx: ${data.transactions.length}');

    final tmp = r'C:\Users\user\dev\inventory_app\bin\roundtrip_test.xlsx';
    ExcelRepo.save(tmp, data.products, data.transactions);
    print('save ok -> $tmp');

    final reloaded = ExcelRepo.load(tmp);
    print('reload ok - products: ${reloaded.products.length}, tx: ${reloaded.transactions.length}');
    File(tmp).deleteSync();
  } catch (e, st) {
    print('ERROR: $e');
    print(st);
  }
}
