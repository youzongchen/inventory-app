import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';
import '../services/download.dart';
import '../services/excel_repo.dart';
import '../services/sheets_repo.dart';

class InventoryState extends ChangeNotifier {
  static const _prefKey = 'base_excel_path';
  static const _sheetsUrlPrefKey = 'sheets_api_url';
  static const _sheetsKeyPrefKey = 'sheets_api_key';
  static const _sheetsSheetUrlPrefKey = 'sheets_sheet_url';

  String? filePath;
  String? webFileName; // web has no real path - just the name to re-download as
  String? sheetsApiUrl; // web only: Google Apps Script Web App URL, if connected
  String? sheetsKey;
  // Optional: the actual Google Sheet URL (as opposed to the Apps Script Web
  // App API URL above) - only used so 庫存管理 dashboard's edit-pencil button
  // has somewhere to open. Not required for the app to function.
  String? sheetsSheetUrl;
  List<Product> products = [];
  List<TxRecord> transactions = [];
  List<PendingScan> session = [];
  bool loading = false;
  String? loadError;

  Future<String?> restoreLastPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKey);
  }

  /// Returns the last-used (apiUrl, key, sheetUrl) triple, or null if never
  /// connected. sheetUrl is optional and may itself be null even when apiUrl/key
  /// aren't.
  Future<(String, String, String?)?> restoreSheetsConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_sheetsUrlPrefKey);
    final key = prefs.getString(_sheetsKeyPrefKey);
    if (url == null || key == null) return null;
    return (url, key, prefs.getString(_sheetsSheetUrlPrefKey));
  }

  /// Connects to a Google Sheets backend (see Code.gs) instead of a local
  /// file - web only. Every save pushes the full products+transactions state
  /// to the Apps Script Web App, which overwrites the sheet, so there's no
  /// more "download a new copy every time" friction. [sheetUrl] is optional -
  /// it's the actual Google Sheet URL (not the Apps Script API URL), kept only
  /// so 庫存管理 dashboard's edit-pencil button has somewhere to open.
  Future<void> loadFromSheets(String apiUrl, String key, {String? sheetUrl}) async {
    loading = true;
    loadError = null;
    notifyListeners();
    try {
      final data = await SheetsRepo.load(apiUrl, key);
      products = data.products;
      transactions = data.transactions;
      filePath = null;
      webFileName = null;
      sheetsApiUrl = apiUrl;
      sheetsKey = key;
      sheetsSheetUrl = (sheetUrl == null || sheetUrl.isEmpty) ? null : sheetUrl;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sheetsUrlPrefKey, apiUrl);
      await prefs.setString(_sheetsKeyPrefKey, key);
      if (sheetsSheetUrl != null) {
        await prefs.setString(_sheetsSheetUrlPrefKey, sheetsSheetUrl!);
      } else {
        await prefs.remove(_sheetsSheetUrlPrefKey);
      }
    } catch (e) {
      loadError = '連線失敗：$e';
    } finally {
      loading = false;
      notifyListeners();
    }
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
      webFileName = null;
      sheetsApiUrl = null;
      sheetsKey = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, path);
    } catch (e) {
      loadError = '讀取失敗：$e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Web has no filesystem paths - loads from bytes picked via a browser
  /// file input instead. [fileName] is kept only so re-saving can offer the
  /// same name for the downloaded copy.
  Future<void> loadFromBytes(Uint8List bytes, String fileName) async {
    loading = true;
    loadError = null;
    notifyListeners();
    try {
      final data = ExcelRepo.loadBytes(bytes);
      products = data.products;
      transactions = data.transactions;
      filePath = null;
      webFileName = fileName;
      sheetsApiUrl = null;
      sheetsKey = null;
    } catch (e) {
      loadError = '讀取失敗：$e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Opens the platform file picker and loads the chosen workbook - a real
  /// path on desktop/mobile, or in-memory bytes on web. Returns true on success.
  Future<bool> pickAndLoadFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      dialogTitle: '選擇庫存 Excel 檔案 (.xlsx)',
      withData: kIsWeb,
    );
    if (result == null) return false;
    final file = result.files.single;
    if (kIsWeb) {
      if (file.bytes == null) return false;
      await loadFromBytes(file.bytes!, file.name);
    } else {
      if (file.path == null) return false;
      await loadFile(file.path!);
    }
    return loadError == null;
  }

  Future<void> _save() async {
    if (sheetsApiUrl != null) {
      await SheetsRepo.save(sheetsApiUrl!, sheetsKey!, products, transactions);
      return;
    }
    if (kIsWeb) {
      if (webFileName == null) return;
      final bytes = ExcelRepo.encodeBytes(products, transactions);
      if (bytes != null) downloadBytes(bytes, webFileName!);
      return;
    }
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

  List<String> get sizes {
    final s = products
        .map((p) => p.size)
        .whereType<String>()
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList();
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

  /// Manually override how many units this one scanned line represents (see
  /// [PendingScan.qty]) - lets the user scan a barcode once and bump the count
  /// instead of scanning the same item repeatedly.
  void setQty(int index, int qty) {
    if (index < 0 || index >= session.length) return;
    session[index].qty = qty < 1 ? 1 : qty;
    notifyListeners();
  }

  void clearSession() {
    session = [];
    notifyListeners();
  }

  Future<void> commitSession(String type) async {
    var nextId = (transactions.isEmpty ? 0 : transactions.map((t) => t.id).reduce((a, b) => a > b ? a : b)) + 1;
    final newRecords = <TxRecord>[];
    for (final s in session) {
      // qty > 1 means the user scanned once but marked it as representing
      // several units - expand into that many rows so 目前庫存 (counted by row)
      // and 交易紀錄 stay consistent with how every other quantity here works.
      for (var i = 0; i < s.qty; i++) {
        newRecords.add(TxRecord(
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
    }
    // Only commit to the in-memory log (and clear the pending session) once
    // the save actually succeeds - otherwise a broken connection would silently
    // wipe the scan session while never persisting it anywhere.
    transactions.addAll(newRecords);
    try {
      await _save();
    } catch (e) {
      transactions.removeRange(transactions.length - newRecords.length, transactions.length);
      rethrow;
    }
    session = [];
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
    final added = delta.abs();
    for (var i = 0; i < added; i++) {
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
    try {
      await _save();
    } catch (e) {
      transactions.removeRange(transactions.length - added, transactions.length);
      rethrow;
    }
    notifyListeners();
  }

  /// Deletes a stock line entirely: removes every 交易紀錄 for [barcode] at
  /// [location], so the row disappears from 總覽/庫存管理 (history included -
  /// this isn't a "reconcile to 0" adjustment, it erases the row itself).
  /// The product master record in 資料庫 is left untouched in case the same
  /// barcode still has stock at another location.
  Future<void> deleteStockRow(String barcode, String location) async {
    transactions.removeWhere((t) => t.barcode == barcode && t.location == location);
    await _save();
    notifyListeners();
  }
}
