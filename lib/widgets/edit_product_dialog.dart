import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../state/inventory_state.dart';

/// Lets the user edit a product's master data (category, brand, cost, ...)
/// and reconcile its current stock quantity at [row.location].
Future<void> showEditProductDialog(BuildContext context, OverviewRow row) {
  return showDialog(
    context: context,
    builder: (_) => EditProductDialog(row: row),
  );
}

class EditProductDialog extends StatefulWidget {
  final OverviewRow row;
  const EditProductDialog({super.key, required this.row});

  @override
  State<EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<EditProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _costCtrl;
  late final TextEditingController _safetyStockCtrl;
  late final TextEditingController _boxQtyCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _noteCtrl;
  late String _category;
  late String _unitType;
  String? _linkedBarcode;
  Product? _originalProduct;

  @override
  void initState() {
    super.initState();
    final p = context.read<InventoryState>().findProduct(widget.row.barcode);
    _originalProduct = p;
    _nameCtrl = TextEditingController(text: p?.name ?? widget.row.name);
    _brandCtrl = TextEditingController(text: p?.brand ?? widget.row.brand);
    _costCtrl = TextEditingController(text: p?.cost?.toStringAsFixed(0) ?? '');
    _safetyStockCtrl = TextEditingController(
      text: p?.safetyStock?.toString() ?? '',
    );
    _boxQtyCtrl = TextEditingController(text: p?.boxQty?.toString() ?? '');
    _qtyCtrl = TextEditingController(text: widget.row.currentQty.toString());
    _noteCtrl = TextEditingController(text: p?.note ?? '');
    _category = p?.category ?? widget.row.category;
    _unitType = p?.unitType ?? '散裝';
    _linkedBarcode = p?.linkedLooseBarcode;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _costCtrl.dispose();
    _safetyStockCtrl.dispose();
    _boxQtyCtrl.dispose();
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Product _buildUpdatedProduct() {
    return Product(
      barcode: widget.row.barcode,
      name: _nameCtrl.text.trim(),
      category: _category,
      brand: _brandCtrl.text.trim(),
      unitType: _unitType,
      boxQty: _unitType == '整箱' ? int.tryParse(_boxQtyCtrl.text) : null,
      linkedLooseBarcode: _unitType == '整箱' ? _linkedBarcode : null,
      cost: double.tryParse(_costCtrl.text),
      safetyStock: int.tryParse(_safetyStockCtrl.text),
      note: _noteCtrl.text.trim(),
    );
  }

  bool _sharedFieldsChanged(Product updated) {
    final o = _originalProduct;
    if (o == null) {
      return true; // brand-new product record - nothing to conflict with
    }
    return o.name != updated.name ||
        o.category != updated.category ||
        o.brand != updated.brand ||
        o.unitType != updated.unitType ||
        o.boxQty != updated.boxQty ||
        o.linkedLooseBarcode != updated.linkedLooseBarcode ||
        o.cost != updated.cost ||
        o.safetyStock != updated.safetyStock ||
        o.note != updated.note;
  }

  Future<bool> _confirmApplyToAllLocations(
    BuildContext context,
    Set<String> locations,
  ) async {
    final firstOk = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('套用到全部地點？'),
        content: Text(
          '條碼 ${widget.row.barcode} 同時存在於：${locations.join('、')}。\n'
          '品名、類別、品牌、成本等資料是共用的，這次修改會套用到全部地點。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('套用到全部'),
          ),
        ],
      ),
    );
    if (firstOk != true || !context.mounted) return false;

    final secondOk = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確定要套用嗎？'),
        content: const Text('此動作將更新資料庫中的共用資料，確定要繼續嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確定'),
          ),
        ],
      ),
    );
    return secondOk == true;
  }

  Future<void> _onSave(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    final inventoryState = context.read<InventoryState>();
    final updated = _buildUpdatedProduct();

    if (_sharedFieldsChanged(updated)) {
      final locations = inventoryState
          .overview()
          .where((r) => r.barcode == widget.row.barcode)
          .map((r) => r.location)
          .toSet();
      if (locations.length > 1) {
        final confirmed = await _confirmApplyToAllLocations(context, locations);
        if (!confirmed) return; // leave the dialog open, nothing saved
      }
    }

    await inventoryState.addOrUpdateProduct(updated);
    final newQty = int.tryParse(_qtyCtrl.text);
    if (newQty != null) {
      await inventoryState.adjustStock(
        widget.row.barcode,
        widget.row.location,
        newQty,
      );
    }
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<InventoryState>();
    final looseProducts = state.products
        .where((p) => p.unitType == '散裝' && p.barcode != widget.row.barcode)
        .toList();

    return AlertDialog(
      scrollable:
          true, // keeps the form reachable when the on-screen keyboard covers half the dialog
      title: const Text('編輯品項'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '條碼：${widget.row.barcode} ・ 地點：${widget.row.location}',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: '品名 *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '請輸入品名' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: '類別'),
                items: kCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _brandCtrl,
                decoration: const InputDecoration(labelText: '品牌'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('是否整箱：'),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('散裝'),
                    selected: _unitType == '散裝',
                    onSelected: (_) => setState(() => _unitType = '散裝'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('整箱'),
                    selected: _unitType == '整箱',
                    onSelected: (_) => setState(() => _unitType = '整箱'),
                  ),
                ],
              ),
              if (_unitType == '整箱') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _linkedBarcode,
                  decoration: const InputDecoration(labelText: '對應的散裝品項'),
                  items: looseProducts
                      .map(
                        (p) => DropdownMenuItem(
                          value: p.barcode,
                          child: Text('${p.name}（${p.barcode}）'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _linkedBarcode = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _boxQtyCtrl,
                  decoration: const InputDecoration(labelText: '一箱等於幾包散裝'),
                  keyboardType: TextInputType.number,
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _costCtrl,
                decoration: const InputDecoration(labelText: '成本'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _safetyStockCtrl,
                decoration: const InputDecoration(
                  labelText: '安全庫存量（低於此數量會標紅提醒）',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _qtyCtrl,
                decoration: InputDecoration(
                  labelText: '目前庫存數量（${widget.row.location}）',
                  helperText: '與原本數量不同時，會自動新增一筆調整紀錄到交易紀錄',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(labelText: '備註'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => _onSave(context),
          child: const Text('儲存'),
        ),
      ],
    );
  }
}
