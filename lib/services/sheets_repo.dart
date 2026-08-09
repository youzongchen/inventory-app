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
      createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? ''),
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
      dateTime: DateTime.tryParse(j['dateTime']?.toString() ?? '') ?? DateTime.now(),
      type: j['type']?.toString() ?? '',
      damaged: j['damaged'] == true || j['damaged']?.toString() == 'true',
      expiryDate: j['expiryDate'] == null || j['expiryDate'].toString().isEmpty
          ? null
          : DateTime.tryParse(j['expiryDate'].toString()),
      note: j['note']?.toString() ?? '',
    );
  }

  static Map<String, dynamic> _txToJson(TxRecord t) => {
        'id': t.id,
        'barcode': t.barcode,
        'name': t.name,
        'location': t.location,
        'dateTime': t.dateTime.toIso8601String(),
        'type': t.type,
        'damaged': t.damaged,
        'expiryDate': t.expiryDate?.toIso8601String(),
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
}
