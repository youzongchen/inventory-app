import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../models.dart';

const _sheetProducts = '資料庫';
const _sheetTx = '交易紀錄';
const _sheetOverview = '總覽';

const _productHeaders = [
  '條碼', '品名', '類別', '品牌', '整箱或散裝', '箱入數',
  '對應散裝條碼', '成本', '售價', '安全庫存量', '建立日期', '備註',
];

const _txHeaders = ['交易編號', '條碼', '品名', '地點', '日期', '時間', '類型', '損壞', '有效期限', '備註'];

const _overviewHeaders = [
  '條碼', '品名', '類別', '品牌', '地點', '目前庫存數量', '累計入庫',
  '累計出庫', '累計損壞數', '成本', '庫存金額', '安全庫存量', '最近效期', '最後異動時間',
];

String _s(CellValue? v) => v == null ? '' : v.toString();

double? _num(CellValue? v) {
  final s = _s(v).trim();
  if (s.isEmpty) return null;
  return double.tryParse(s);
}

int? _int(CellValue? v) {
  final d = _num(v);
  return d?.round();
}

CellValue? _cv(Object? v) {
  if (v == null) return null;
  if (v is String) return v.isEmpty ? null : TextCellValue(v);
  if (v is int) return IntCellValue(v);
  if (v is double) return DoubleCellValue(v);
  if (v is DateTime) return DateTimeCellValue.fromDateTime(v);
  return TextCellValue(v.toString());
}

class LoadedInventory {
  final List<Product> products;
  final List<TxRecord> transactions;
  LoadedInventory(this.products, this.transactions);
}

class ExcelRepo {
  /// Reads the workbook at [path] and returns the product master + tx log.
  /// Desktop/mobile only - web has no filesystem paths, use [loadBytes].
  static LoadedInventory load(String path) {
    return loadBytes(File(path).readAsBytesSync());
  }

  /// Reads a workbook already in memory (e.g. bytes picked via a web file
  /// input) and returns the product master + tx log. If the workbook doesn't
  /// have the expected sheets yet, returns empty lists so a brand-new base
  /// file can be adopted.
  static LoadedInventory loadBytes(Uint8List bytes) {
    final wb = Excel.decodeBytes(bytes);

    final products = <Product>[];
    final productSheet = wb.sheets[_sheetProducts];
    if (productSheet != null) {
      for (final row in productSheet.rows.skip(1)) {
        if (row.isEmpty) continue;
        final barcode = _s(row.elementAtOrNull(0)?.value);
        if (barcode.isEmpty) continue;
        products.add(Product(
          barcode: barcode,
          name: _s(row.elementAtOrNull(1)?.value),
          category: _s(row.elementAtOrNull(2)?.value).isEmpty
              ? '待分類'
              : _s(row.elementAtOrNull(2)?.value),
          brand: _s(row.elementAtOrNull(3)?.value),
          unitType: _s(row.elementAtOrNull(4)?.value).isEmpty
              ? '散裝'
              : _s(row.elementAtOrNull(4)?.value),
          boxQty: _int(row.elementAtOrNull(5)?.value),
          linkedLooseBarcode: _s(row.elementAtOrNull(6)?.value).isEmpty
              ? null
              : _s(row.elementAtOrNull(6)?.value),
          cost: _num(row.elementAtOrNull(7)?.value),
          price: _num(row.elementAtOrNull(8)?.value),
          safetyStock: _int(row.elementAtOrNull(9)?.value),
          createdAt: DateTime.tryParse(_s(row.elementAtOrNull(10)?.value)),
          note: _s(row.elementAtOrNull(11)?.value),
        ));
      }
    }

    final tx = <TxRecord>[];
    final txSheet = wb.sheets[_sheetTx];
    if (txSheet != null) {
      for (final row in txSheet.rows.skip(1)) {
        if (row.isEmpty) continue;
        final barcode = _s(row.elementAtOrNull(1)?.value);
        if (barcode.isEmpty) continue;
        final dateStr = _s(row.elementAtOrNull(4)?.value);
        final timeStr = _s(row.elementAtOrNull(5)?.value);
        final dt = _parseDateTime(dateStr, timeStr);
        tx.add(TxRecord(
          id: _int(row.elementAtOrNull(0)?.value) ?? (tx.length + 1),
          barcode: barcode,
          name: _s(row.elementAtOrNull(2)?.value),
          location: _s(row.elementAtOrNull(3)?.value).isEmpty
              ? '家裡'
              : _s(row.elementAtOrNull(3)?.value),
          dateTime: dt,
          type: _s(row.elementAtOrNull(6)?.value),
          damaged: _s(row.elementAtOrNull(7)?.value) == '是',
          expiryDate: _parseDateOnly(_s(row.elementAtOrNull(8)?.value)),
          note: _s(row.elementAtOrNull(9)?.value),
        ));
      }
    }

    return LoadedInventory(products, tx);
  }

  static DateTime _parseDateTime(String dateStr, String timeStr) {
    try {
      final dParts = dateStr.split(RegExp(r'[/-]')).map(int.parse).toList();
      var h = 0, mi = 0, se = 0;
      if (timeStr.isNotEmpty) {
        final tParts = timeStr.split(':').map((e) => int.tryParse(e) ?? 0).toList();
        h = tParts.elementAtOrNull(0) ?? 0;
        mi = tParts.elementAtOrNull(1) ?? 0;
        se = tParts.elementAtOrNull(2) ?? 0;
      }
      if (dParts.length == 3) {
        return DateTime(dParts[0], dParts[1], dParts[2], h, mi, se);
      }
    } catch (_) {}
    return DateTime.now();
  }

  static DateTime? _parseDateOnly(String s) {
    if (s.trim().isEmpty) return null;
    try {
      final parts = s.split(RegExp(r'[/-]')).map(int.parse).toList();
      if (parts.length == 3) return DateTime(parts[0], parts[1], parts[2]);
    } catch (_) {}
    return null;
  }

  /// Writes products + transactions + a freshly computed overview back to [path].
  /// Desktop/mobile only - web has no filesystem paths, use [encodeBytes].
  static void save(String path, List<Product> products, List<TxRecord> tx) {
    final bytes = encodeBytes(products, tx);
    if (bytes != null) {
      File(path).writeAsBytesSync(bytes);
    }
  }

  /// Builds the .xlsx bytes for products + transactions + a freshly computed
  /// overview, without touching the filesystem. Used directly on web (the
  /// caller triggers a browser download) and internally by [save].
  static Uint8List? encodeBytes(List<Product> products, List<TxRecord> tx) {
    final wb = Excel.createExcel();

    final ps = wb[_sheetProducts];
    ps.appendRow(_productHeaders.map((h) => TextCellValue(h) as CellValue?).toList());
    for (final p in products) {
      ps.appendRow([
        _cv(p.barcode),
        _cv(p.name),
        _cv(p.category),
        _cv(p.brand),
        _cv(p.unitType),
        _cv(p.boxQty),
        _cv(p.linkedLooseBarcode),
        _cv(p.cost),
        _cv(p.price),
        _cv(p.safetyStock),
        _cv(p.createdAt?.toIso8601String().substring(0, 10)),
        _cv(p.note),
      ]);
    }

    final txs = wb[_sheetTx];
    txs.appendRow(_txHeaders.map((h) => TextCellValue(h) as CellValue?).toList());
    for (final t in tx) {
      txs.appendRow([
        _cv(t.id),
        _cv(t.barcode),
        _cv(t.name),
        _cv(t.location),
        _cv('${t.dateTime.year}/${t.dateTime.month}/${t.dateTime.day}'),
        _cv('${t.dateTime.hour.toString().padLeft(2, '0')}:${t.dateTime.minute.toString().padLeft(2, '0')}'),
        _cv(t.type),
        _cv(t.damaged ? '是' : '否'),
        _cv(t.expiryDate == null
            ? null
            : '${t.expiryDate!.year}/${t.expiryDate!.month}/${t.expiryDate!.day}'),
        _cv(t.note),
      ]);
    }

    final overview = computeOverview(products, tx);
    final os = wb[_sheetOverview];
    os.appendRow(_overviewHeaders.map((h) => TextCellValue(h) as CellValue?).toList());
    for (final o in overview) {
      os.appendRow([
        _cv(o.barcode),
        _cv(o.name),
        _cv(o.category),
        _cv(o.brand),
        _cv(o.location),
        _cv(o.currentQty),
        _cv(o.totalIn),
        _cv(o.totalOut),
        _cv(o.damagedQty),
        _cv(o.cost),
        _cv(o.stockValue),
        _cv(o.safetyStock),
        _cv(o.nearestExpiry == null
            ? null
            : '${o.nearestExpiry!.year}/${o.nearestExpiry!.month}/${o.nearestExpiry!.day}'),
        _cv(o.lastActivity?.toIso8601String()),
      ]);
    }

    wb.delete('Sheet1');
    final bytes = wb.encode();
    return bytes == null ? null : Uint8List.fromList(bytes);
  }

  static List<OverviewRow> computeOverview(List<Product> products, List<TxRecord> tx) {
    final byBarcodeProduct = {for (final p in products) p.barcode: p};
    final groups = <String, List<TxRecord>>{};
    for (final t in tx) {
      final key = '${t.barcode}|${t.location}';
      groups.putIfAbsent(key, () => []).add(t);
    }

    final rows = <OverviewRow>[];
    groups.forEach((key, records) {
      final barcode = records.first.barcode;
      final location = records.first.location;
      final product = byBarcodeProduct[barcode];
      final totalIn = records.where((r) => r.type == '入').length;
      final totalOut = records.where((r) => r.type == '出').length;
      final damagedQty = records.where((r) => r.damaged).length;
      final damagedIn = records.where((r) => r.type == '入' && r.damaged).length;
      final damagedOut = records.where((r) => r.type == '出' && r.damaged).length;
      final damagedInStock = (damagedIn - damagedOut).clamp(0, 1 << 30);
      records.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      final expiries = records
          .where((r) => r.type == '入' && r.expiryDate != null)
          .map((r) => r.expiryDate!)
          .toList()
        ..sort();
      rows.add(OverviewRow(
        barcode: barcode,
        name: product?.name ?? records.first.name,
        category: product?.category ?? '待分類',
        brand: product?.brand ?? '',
        location: location,
        currentQty: totalIn - totalOut,
        totalIn: totalIn,
        totalOut: totalOut,
        damagedQty: damagedQty,
        damagedInStock: damagedInStock,
        cost: product?.cost,
        safetyStock: product?.safetyStock,
        lastActivity: records.last.dateTime,
        nearestExpiry: expiries.isEmpty ? null : expiries.first,
      ));
    });
    rows.sort((a, b) {
      final c = a.category.compareTo(b.category);
      return c != 0 ? c : a.name.compareTo(b.name);
    });
    return rows;
  }
}

extension _ElementAtOrNull<T> on List<T> {
  T? elementAtOrNull(int index) => index >= 0 && index < length ? this[index] : null;
}
