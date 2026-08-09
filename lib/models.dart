const kCategories = ['尿布', '雜貨', '清潔用品', '食品', '其他', '待分類'];
const kLocations = ['家裡', '公司'];

class Product {
  String barcode;
  String name;
  String category;
  String brand;
  String unitType; // '散裝' or '整箱'
  int? boxQty; // 箱入數 - only meaningful when unitType == '整箱'
  String? linkedLooseBarcode; // 對應散裝條碼 - only meaningful when unitType == '整箱'
  double? cost;
  double? price;
  int? safetyStock; // 安全庫存量, low-stock alert threshold
  DateTime? createdAt;
  String note;

  Product({
    required this.barcode,
    required this.name,
    this.category = '待分類',
    this.brand = '',
    this.unitType = '散裝',
    this.boxQty,
    this.linkedLooseBarcode,
    this.cost,
    this.price,
    this.safetyStock,
    DateTime? createdAt,
    this.note = '',
  }) : createdAt = createdAt ?? DateTime.now();
}

class TxRecord {
  int id;
  String barcode;
  String name;
  String location;
  DateTime dateTime;
  String type; // '入' or '出'
  bool damaged;
  String note;
  DateTime? expiryDate; // 有效期限, optional

  TxRecord({
    required this.id,
    required this.barcode,
    required this.name,
    required this.location,
    required this.dateTime,
    required this.type,
    this.damaged = false,
    this.note = '',
    this.expiryDate,
  });
}

class OverviewRow {
  final String barcode;
  final String name;
  final String category;
  final String brand;
  final String location;
  final int currentQty;
  final int totalIn;
  final int totalOut;
  final int damagedQty; // 累計損壞: all-time count of transactions flagged 損壞
  final int damagedInStock; // 損壞在庫: damaged units not yet removed again via 出
  final double? cost;
  final int? safetyStock;
  final DateTime? lastActivity;
  final DateTime? nearestExpiry; // soonest 有效期限 recorded among 入 transactions

  OverviewRow({
    required this.barcode,
    required this.name,
    required this.category,
    required this.brand,
    required this.location,
    required this.currentQty,
    required this.totalIn,
    required this.totalOut,
    required this.damagedQty,
    this.damagedInStock = 0,
    this.cost,
    this.safetyStock,
    this.lastActivity,
    this.nearestExpiry,
  });

  double get stockValue => (cost ?? 0) * currentQty;
  bool get isLowStock => safetyStock != null && currentQty <= safetyStock!;
  int get goodQty => (currentQty - damagedInStock).clamp(0, currentQty);
}

// A row currently being built up on the scan screen, before it is committed
// to the transaction log.
class PendingScan {
  String barcode;
  String name;
  String location;
  DateTime time;
  String note;
  bool locked;
  bool damaged;
  DateTime? expiryDate; // 有效期限, optional

  PendingScan({
    required this.barcode,
    required this.name,
    required this.location,
    required this.time,
    this.note = '',
    this.locked = true,
    this.damaged = false,
    this.expiryDate,
  });
}
