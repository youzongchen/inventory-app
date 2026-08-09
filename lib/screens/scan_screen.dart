import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/inventory_state.dart';
import '../widgets/new_product_dialog.dart';
import 'barcode_camera_screen.dart';

final bool _kHasCamera = defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

class ScanScreen extends StatefulWidget {
  final String mode; // 'in' or 'out'
  final String location;
  const ScanScreen({super.key, required this.mode, required this.location});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _barcodeCtrl = TextEditingController();
  final _barcodeFocus = FocusNode();
  int? _selectedIndex;

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _barcodeFocus.dispose();
    super.dispose();
  }

  Future<void> _handleScan(String rawValue) async {
    final barcode = rawValue.trim();
    _barcodeCtrl.clear();
    if (barcode.isEmpty) return;

    final state = context.read<InventoryState>();
    final product = state.findProduct(barcode);
    if (product == null) {
      final added = await showNewProductDialog(context, barcode);
      if (added == null) {
        _barcodeFocus.requestFocus();
        return; // user cancelled - don't add to session
      }
    }
    state.addScanToSession(barcode, widget.location);
    _barcodeFocus.requestFocus();
  }

  Future<void> _scanWithCamera() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeCameraScreen()),
    );
    if (result != null && result.isNotEmpty) {
      await _handleScan(result);
    } else {
      _barcodeFocus.requestFocus();
    }
  }

  Future<void> _pickExpiryDate(int index) async {
    final row = context.read<InventoryState>().session[index];
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: row.expiryDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) {
      setState(() => row.expiryDate = picked);
    }
  }

  Future<void> _complete() async {
    final state = context.read<InventoryState>();
    if (state.session.isEmpty) return;
    final type = widget.mode == 'in' ? '入' : '出';
    final count = state.session.length;
    await state.commitSession(type);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已登錄 $count 筆紀錄')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<InventoryState>();
    final title = widget.mode == 'in' ? '進貨' : '出貨';

    return Scaffold(
      appBar: AppBar(title: Text('$title - ${widget.location}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcodeCtrl,
                    focusNode: _barcodeFocus,
                    autofocus: true,
                    // Force a numeric keypad so a phone's default Chinese IME (Zhuyin etc.)
                    // never intercepts/composes the raw keystrokes coming from a barcode
                    // gun or the manual entry - all barcodes here are numeric (EAN/UPC).
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '條碼機掃描 / 手動輸入條碼後按 Enter',
                      prefixIcon: Icon(Icons.qr_code_scanner),
                      border: OutlineInputBorder(),
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onSubmitted: _handleScan,
                  ),
                ),
                if (_kHasCamera) ...[
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _scanWithCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('相機掃描'),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: state.session.isEmpty
                ? const Center(child: Text('尚未掃描任何項目', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: state.session.length,
                    itemBuilder: (context, index) {
                      final row = state.session[index];
                      final selected = _selectedIndex == index;
                      return Material(
                        color: selected ? Colors.blue.withValues(alpha: 0.08) : null,
                        child: InkWell(
                          onTap: () => setState(() => _selectedIndex = index),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(row.locked ? Icons.lock : Icons.lock_open),
                                      tooltip: row.locked ? '解鎖以編輯' : '鎖定',
                                      onPressed: () => state.toggleLock(index),
                                    ),
                                    Expanded(
                                      child: Text(
                                        '${row.name}  ·  ${row.barcode}',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 48, right: 4, bottom: 6),
                                  child: Row(
                                    children: [
                                      Chip(
                                        label: Text(row.location, style: const TextStyle(fontSize: 11)),
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        padding: EdgeInsets.zero,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${row.time.month}/${row.time.day} ${row.time.hour.toString().padLeft(2, '0')}:${row.time.minute.toString().padLeft(2, '0')}',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                      const SizedBox(width: 12),
                                      InkWell(
                                        onTap: () => _pickExpiryDate(index),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.event, size: 14, color: Colors.grey),
                                            const SizedBox(width: 2),
                                            Text(
                                              row.expiryDate == null
                                                  ? '效期'
                                                  : '${row.expiryDate!.year}/${row.expiryDate!.month}/${row.expiryDate!.day}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: row.expiryDate == null ? Colors.grey : Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () => setState(() => row.damaged = !row.damaged),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Checkbox(
                                              value: row.damaged,
                                              visualDensity: VisualDensity.compact,
                                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              activeColor: Colors.orange.shade800,
                                              onChanged: (v) => setState(() => row.damaged = v ?? false),
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              '毀損',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: row.damaged ? Colors.orange.shade800 : Colors.grey,
                                                fontWeight: row.damaged ? FontWeight.bold : null,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: row.note,
                                          decoration: const InputDecoration(hintText: '備註', isDense: true),
                                          onChanged: (v) => row.note = v,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text('共 ${state.session.length} 筆', style: const TextStyle(color: Colors.grey)),
                OutlinedButton.icon(
                  onPressed: state.session.isEmpty ? null : state.undoLastScan,
                  icon: const Icon(Icons.undo),
                  label: const Text('復原'),
                ),
                OutlinedButton.icon(
                  onPressed: _selectedIndex == null
                      ? null
                      : () {
                          state.removeAt(_selectedIndex!);
                          setState(() => _selectedIndex = null);
                        },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('刪除'),
                ),
                FilledButton.icon(
                  onPressed: state.session.isEmpty ? null : _complete,
                  icon: const Icon(Icons.check),
                  label: const Text('完成登錄'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
