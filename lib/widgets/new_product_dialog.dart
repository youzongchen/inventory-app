import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../state/inventory_state.dart';

/// Shown when a scanned barcode has no match in 資料庫.
/// Returns the newly created Product, or null if cancelled.
Future<Product?> showNewProductDialog(BuildContext context, String barcode) {
  return showDialog<Product>(
    context: context,
    barrierDismissible: false,
    builder: (_) => NewProductDialog(barcode: barcode),
  );
}

class NewProductDialog extends StatefulWidget {
  final String barcode;
  const NewProductDialog({super.key, required this.barcode});

  @override
  State<NewProductDialog> createState() => _NewProductDialogState();
}

class _NewProductDialogState extends State<NewProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController(text: kCategories.first);
  final _brandCtrl = TextEditingController();
  final _sizeCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _marginCtrl = TextEditingController();
  final _boxQtyCtrl = TextEditingController();
  String _unitType = '散裝';
  String? _linkedBarcode;
  bool _useMarginCalc = false;

  @override
  void initState() {
    super.initState();
    _costCtrl.addListener(_recomputeAutoPrice);
    _marginCtrl.addListener(_recomputeAutoPrice);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _brandCtrl.dispose();
    _sizeCtrl.dispose();
    _costCtrl.dispose();
    _priceCtrl.dispose();
    _marginCtrl.dispose();
    _boxQtyCtrl.dispose();
    super.dispose();
  }

  void _recomputeAutoPrice() {
    if (!_useMarginCalc) return;
    final cost = double.tryParse(_costCtrl.text);
    final margin = double.tryParse(_marginCtrl.text);
    if (cost == null || margin == null) return;
    _priceCtrl.text = (cost * (1 + margin / 100)).toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<InventoryState>();
    final looseProducts = state.products
        .where((p) => p.unitType == '散裝')
        .toList();

    return AlertDialog(
      scrollable:
          true, // keeps the form reachable when the on-screen keyboard covers half the dialog
      title: const Text('新條碼，資料庫無此項目'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '條碼：${widget.barcode}',
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
              Autocomplete<String>(
                optionsBuilder: (v) {
                  final opts = <String>{...kCategories, ...state.categories};
                  if (v.text.trim().isEmpty) return opts;
                  return opts.where(
                    (c) => c.toLowerCase().contains(v.text.trim().toLowerCase()),
                  );
                },
                initialValue: TextEditingValue(text: _categoryCtrl.text),
                onSelected: (v) => _categoryCtrl.text = v,
                fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                  controller.addListener(() => _categoryCtrl.text = controller.text);
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(labelText: '類別（可從選單選或直接輸入新的）'),
                  );
                },
              ),
              const SizedBox(height: 12),
              Autocomplete<String>(
                optionsBuilder: (v) {
                  if (v.text.trim().isEmpty) return state.brands;
                  return state.brands.where(
                    (b) => b.toLowerCase().contains(v.text.trim().toLowerCase()),
                  );
                },
                onSelected: (v) => _brandCtrl.text = v,
                fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                  // Keep our own controller in sync so the submit handler can read it.
                  controller.addListener(() => _brandCtrl.text = controller.text);
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(labelText: '品牌（選填，可從既有品牌選或直接輸入新的）'),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sizeCtrl,
                decoration: const InputDecoration(labelText: '尺寸（選填）'),
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
                  decoration: const InputDecoration(
                    labelText: '對應的散裝品項（若尚未建立可留空）',
                  ),
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
                decoration: const InputDecoration(labelText: '成本（選填）'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: _useMarginCalc,
                    onChanged: (v) => setState(() {
                      _useMarginCalc = v ?? false;
                      _recomputeAutoPrice();
                    }),
                  ),
                  const Expanded(child: Text('用利潤 % 自動換算訂價（勾選後輸入利潤%，訂價會即時算出）')),
                ],
              ),
              if (_useMarginCalc) ...[
                TextFormField(
                  controller: _marginCtrl,
                  decoration: const InputDecoration(labelText: '想賺的利潤 %'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _priceCtrl,
                enabled: !_useMarginCalc,
                decoration: InputDecoration(
                  labelText: '訂價（選填）',
                  helperText: _useMarginCalc ? '由成本 × (1+利潤%) 自動算出' : null,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;
            final product = Product(
              barcode: widget.barcode,
              name: _nameCtrl.text.trim(),
              category: _categoryCtrl.text.trim().isEmpty ? '待分類' : _categoryCtrl.text.trim(),
              brand: _brandCtrl.text.trim(),
              size: _sizeCtrl.text.trim().isEmpty ? null : _sizeCtrl.text.trim(),
              unitType: _unitType,
              boxQty: _unitType == '整箱' ? int.tryParse(_boxQtyCtrl.text) : null,
              linkedLooseBarcode: _unitType == '整箱' ? _linkedBarcode : null,
              cost: double.tryParse(_costCtrl.text),
              price: double.tryParse(_priceCtrl.text),
            );
            try {
              await context.read<InventoryState>().addOrUpdateProduct(product);
              if (context.mounted) Navigator.pop(context, product);
            } catch (e) {
              // Keep the dialog open on failure (e.g. Sheets connection
              // broken) instead of looking stuck with no feedback at all.
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('存檔失敗：$e')),
                );
              }
            }
          },
          child: const Text('新增'),
        ),
      ],
    );
  }
}
