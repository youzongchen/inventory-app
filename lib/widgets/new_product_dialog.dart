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
  final _brandCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _boxQtyCtrl = TextEditingController();
  String _category = kCategories.first;
  String _unitType = '散裝';
  String? _linkedBarcode;

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
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: '類別'),
                items: kCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
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
              category: _category,
              brand: _brandCtrl.text.trim(),
              unitType: _unitType,
              boxQty: _unitType == '整箱' ? int.tryParse(_boxQtyCtrl.text) : null,
              linkedLooseBarcode: _unitType == '整箱' ? _linkedBarcode : null,
              cost: double.tryParse(_costCtrl.text),
            );
            await context.read<InventoryState>().addOrUpdateProduct(product);
            if (context.mounted) Navigator.pop(context, product);
          },
          child: const Text('新增'),
        ),
      ],
    );
  }
}
