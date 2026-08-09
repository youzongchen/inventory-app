import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';
import '../services/excel_repo.dart';

class InventoryState extends ChangeNotifier {
  static const _prefKey = 'base_excel_path';

  String? filePath;
  List<Product> products = [];
  List<TxRecord> transactions = [];
  List<PendingScan> session = [];
  bool loading = false;
  String? loadError;

  Future<String?> restoreLastPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKey);
  }

  Future<void> loadFile(String path) async {
    loading = true;
    loadError = null;
    notifyListeners();
    try {
      final data = ExcelRepo.load(path);
      products = data.products;
      transactions = data.transactions;
      filePath = path;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, path);
    } catch (e) {
      loadError = '讀取失敗：$e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _save() async {
    if (filePath == null) return;
    ExcelRepo.save(filePath!, products, transactions);
  }

  Product? findProduct(String barcode) {
    try {
      return products.firstWhere((p) => p.barcode == barcode);
    } catch (_) {
      return null;
    }
  }

  Future<void> addOrUpdateProduct(Product p) async {
    final idx = products.indexWhere((e) => e.barcode == p.barcode);
    if (idx >= 0) {
      products[idx] = p;
    } else {
      products.add(p);
    }
    await _save();
    notifyListeners();
  }

  List<String> get categories {
    final s = products.map((p) => p.category).toSet().toList();
    s.sort();
    return s;
  }

  List<String> get brands {
    final s = products.map((p) => p.brand).where((b) => b.isNotEmpty).toSet().toList();
    s.sort();
    return s;
  }

  // ---- Scan session (used by 進貨/出貨 screen) ----

  void addScanToSession(String barcode, String location) {
    final p = findProduct(barcode);
    session.add(PendingScan(
      barcode: barcode,
      name: p?.name ?? barcode,
      location: location,
      time: DateTime.now(),
    ));
    notifyListeners();
  }

  void undoLastScan() {
    if (session.isNotEmpty) {
      session.removeLast();
      notifyListeners();
    }
  }

  void removeAt(int index) {
    if (index >= 0 && index < session.length) {
      session.removeAt(index);
      notifyListeners();
    }
  }

  void toggleLock(int index) {
    session[index].locked = !session[index].locked;
    notifyListeners();
  }

  void clearSession() {
    session = [];
    notifyListeners();
  }

  Future<void> commitSession(String type) async {
    var nextId = (transactions.isEmpty ? 0 : transactions.map((t) => t.id).reduce((a, b) => a > b ? a : b)) + 1;
    for (final s in session) {
      transactions.add(TxRecord(
        id: nextId++,
        barcode: s.barcode,
        name: s.name,
        location: s.location,
        dateTime: s.time,
        type: type,
        damaged: s.damaged,
        note: s.note,
        expiryDate: s.expiryDate,
      ));
    }
    session = [];
    await _save();
    notifyListeners();
  }

  List<OverviewRow> overview({String? location, String? category}) {
    var rows = ExcelRepo.computeOverview(products, transactions);
    if (location != null && location != '全部') {
      rows = rows.where((r) => r.location == location).toList();
    }
    if (category != null && category != '全部') {
      rows = rows.where((r) => r.category == category).toList();
    }
    return rows;
  }

  // ---- Manual edits from the 庫存管理 dashboard ----

  int _nextTxId() =>
      (transactions.isEmpty ? 0 : transactions.map((t) => t.id).reduce((a, b) => a > b ? a : b)) + 1;

  /// Reconciles the stock at [barcode]/[location] to [newQty] by appending
  /// enough 入/出 rows to the transaction log (every row here represents one
  /// unit, matching how scanning already records history) so the change stays
  /// visible in 交易紀錄 as a normal, auditable entry instead of rewriting history.
  Future<void> adjustStock(String barcode, String location, int newQty, {String note = '庫存調整'}) async {
    final current = overview().firstWhere(
      (r) => r.barcode == barcode && r.location == location,
      orElse: () => OverviewRow(
        barcode: barcode,
        name: findProduct(barcode)?.name ?? barcode,
        category: findProduct(barcode)?.category ?? '待分類',
        brand: findProduct(barcode)?.brand ?? '',
        location: location,
        currentQty: 0,
        totalIn: 0,
        totalOut: 0,
        damagedQty: 0,
      ),
    );
    final delta = newQty - current.currentQty;
    if (delta == 0) return;
    var nextId = _nextTxId();
    final name = findProduct(barcode)?.name ?? current.name;
    for (var i = 0; i < delta.abs(); i++) {
      transactions.add(TxRecord(
        id: nextId++,
        barcode: barcode,
        name: name,
        location: location,
        dateTime: DateTime.now(),
        type: delta > 0 ? '入' : '出',
        note: note,
      ));
    }
    await _save();
    notifyListeners();
  }
}
