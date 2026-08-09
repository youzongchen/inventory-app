import '../lib/services/excel_repo.dart';
void main() {
  final data = ExcelRepo.load(r'D:\User\Desktop\TASK\庫存管理.xlsx');
  print('products: ${data.products.length}');
  final noBrand = data.products.where((p) => p.brand.isEmpty).length;
  print('no brand: $noBrand');
  for (final p in data.products.take(5)) {
    print('${p.barcode} ${p.name} 品牌=${p.brand} 類別=${p.category}');
  }
}
