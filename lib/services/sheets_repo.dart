import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models.dart';
import 'excel_repo.dart' show LoadedInventory;

/// Talks to the Google Apps Script Web App backend (see Code.gs) so the web
/// build can read/write a Google Sheet instead of downloading a fresh .xlsx
/// every time. Desktop/mobile keep using the local-file ExcelRepo.
class SheetsRepo {
  static Future<LoadedInventory> load(String apiUrl, String key) async {
    final base = Uri.parse(apiUrl);
    final uri = base.replace(queryParameters: {...base.queryParameters, 'key': key});
    final resp = await http.get(uri);
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (body['error'] != null) throw Exception(body['error']);

    final products = (body['products'] as List)
        .map((p) => _productFromJson(p as Map<String, dynamic>))
        .toList();
    final tx = (body['transactions'] as List)
        .map((t) => _txFromJson(t as Map<String, dynamic>))
        .toList();
    return LoadedInventory(products, tx);
  }

  static Future<void> save(
    String apiUrl,
    String key,
    List<Product> products,
    List<TxRecord> tx,
  ) async {
    final payload = {
      'key': key,
      'products': products.map(_productToJson).toList(),
      'transactions': tx.map(_txToJson).toList(),
    };
    final resp = await http.post(
      Uri.parse(apiUrl),
      // text/plain avoids a CORS preflight that Apps Script Web Apps don't
      // handle - the body is still JSON text, GAS just parses it manually.
      headers: {'Content-Type': 'text/plain;charset=utf-8'},
      body: jsonEncode(payload),
    );
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (body['error'] != null) throw Exception(body['error']);
  }

  static Product _productFromJson(Map<String, dynamic> j) {
    return Product(
      barcode: j['barcode']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      category: (j['category']?.toString().isEmpty ?? true) ? '待分類' : j['category'].toString(),
      brand: j['brand']?.toString() ?? '',
      unitType: (j['unitType']?.toString().isEmpty ?? true) ? '散裝' : j['unitType'].toString(),
      boxQty: _toInt(j['boxQty']),
      linkedLooseBarcode: (j['linkedLooseBarcode']?.toString().isEmpty ?? true) ? null : j['linkedLooseBarcode'].toString(),
      cost: _toDouble(j['cost']),
      price: _toDouble(j['price']),
      safetyStock: _toInt(j['safetyStock']),
      createdAt: _parseFlexibleDate(j['createdAt']),
      note: j['note']?.toString() ?? '',
    );
  }

  static Map<String, dynamic> _productToJson(Product p) => {
        'barcode': p.barcode,
        'name': p.name,
        'category': p.category,
        'brand': p.brand,
        'unitType': p.unitType,
        'boxQty': p.boxQty,
        'linkedLooseBarcode': p.linkedLooseBarcode,
        'cost': p.cost,
        'price': p.price,
        'safetyStock': p.safetyStock,
        'createdAt': p.createdAt?.toIso8601String(),
        'note': p.note,
      };

  static TxRecord _txFromJson(Map<String, dynamic> j) {
    return TxRecord(
      id: _toInt(j['id']) ?? 0,
      barcode: j['barcode']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      location: (j['location']?.toString().isEmpty ?? true) ? '家裡' : j['location'].toString(),
      dateTime: _parseDateAndTime(j['date'], j['time']),
      type: j['type']?.toString() ?? '',
      damaged: j['damaged'] == true || j['damaged']?.toString() == 'true' || j['damaged']?.toString() == '是',
      expiryDate: _parseFlexibleDate(j['expiryDate']),
      note: j['note']?.toString() ?? '',
    );
  }

  static Map<String, dynamic> _txToJson(TxRecord t) => {
        'id': t.id,
        'barcode': t.barcode,
        'name': t.name,
        'location': t.location,
        'date': '${t.dateTime.year}/${t.dateTime.month}/${t.dateTime.day}',
        'time':
            '${t.dateTime.hour.toString().padLeft(2, '0')}:${t.dateTime.minute.toString().padLeft(2, '0')}',
        'type': t.type,
        'damaged': t.damaged,
        'expiryDate': t.expiryDate == null
            ? null
            : '${t.expiryDate!.year}/${t.expiryDate!.month}/${t.expiryDate!.day}',
        'note': t.note,
      };

  static int? _toInt(Object? v) {
    if (v == null || v == '') return null;
    if (v is num) return v.round();
    return int.tryParse(v.toString());
  }

  static double? _toDouble(Object? v) {
    if (v == null || v == '') return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  /// Google Sheets may have auto-typed a "2026/5/6"-looking column as an
  /// actual Date, in which case Apps Script hands it back as a full ISO
  /// string instead of the plain text we'd get from a manually-typed cell.
  /// Handle both.
  static DateTime? _parseFlexibleDate(Object? v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
    final parts = s.split(RegExp(r'[/-]'));
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) return DateTime(y, m, d);
    }
    return null;
  }

  /// Same idea, but for a time-only value: Google Sheets represents a bare
  /// time as a Date on the 1899-12-30 epoch, so an ISO string here only
  /// contributes its hour/minute/second, not its date.
  static DateTime _parseDateAndTime(Object? dateVal, Object? timeVal) {
    final date = _parseFlexibleDate(dateVal) ?? DateTime.now();
    final timeStr = timeVal?.toString().trim() ?? '';
    if (timeStr.isEmpty) return date;

    final isoTime = DateTime.tryParse(timeStr);
    if (isoTime != null) {
      return DateTime(date.year, date.month, date.day, isoTime.hour, isoTime.minute, isoTime.second);
    }
    final tParts = timeStr.split(':');
    final h = int.tryParse(tParts.elementAtOrNull(0) ?? '') ?? 0;
    final mi = int.tryParse(tParts.elementAtOrNull(1) ?? '') ?? 0;
    final se = int.tryParse(tParts.elementAtOrNull(2) ?? '') ?? 0;
    return DateTime(date.year, date.month, date.day, h, mi, se);
  }
}

extension _ElementAtOrNull<T> on List<T> {
  T? elementAtOrNull(int index) => index >= 0 && index < length ? this[index] : null;
}
