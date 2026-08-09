import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/inventory_state.dart';
import 'home_screen.dart';

class StartupScreen extends StatefulWidget {
  /// Whether to silently reconnect to the last-used source (local path /
  /// Google Sheet). True on cold app start; false when the user explicitly
  /// navigated back here via "切換資料來源" wanting to pick something else.
  final bool autoRestore;

  const StartupScreen({super.key, this.autoRestore = true});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  final _urlCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  bool _showSheetsForm = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final state = context.read<InventoryState>();
    if (kIsWeb) {
      // Pre-fill the Sheets form either way so switching to it doesn't start blank.
      final sheets = await state.restoreSheetsConfig();
      if (sheets != null) {
        final (url, key) = sheets;
        _urlCtrl.text = url;
        _keyCtrl.text = key;
      }
      // Web has no persisted local file path, but a previously-connected
      // Google Sheet is worth silently reconnecting to - unless the user
      // explicitly came back here to pick something else.
      if (widget.autoRestore && sheets != null) {
        final (url, key) = sheets;
        await state.loadFromSheets(url, key);
        if (state.loadError == null && mounted) {
          _goHome();
          return;
        }
      }
      if (mounted) setState(() {});
      return;
    }
    if (!widget.autoRestore) return;
    final lastPath = await state.restoreLastPath();
    if (lastPath != null) {
      await state.loadFile(lastPath);
      if (state.loadError == null && mounted) {
        _goHome();
        return;
      }
    }
    if (mounted) setState(() {});
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _pickFile() async {
    final state = context.read<InventoryState>();
    final ok = await state.pickAndLoadFile();
    if (ok && mounted) {
      _goHome();
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _connectSheets() async {
    final url = _urlCtrl.text.trim();
    final key = _keyCtrl.text.trim();
    if (url.isEmpty || key.isEmpty) return;
    final state = context.read<InventoryState>();
    await state.loadFromSheets(url, key);
    if (state.loadError == null && mounted) {
      _goHome();
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<InventoryState>();
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.inventory_2_outlined, size: 72, color: Color(0xFF2F5597)),
                const SizedBox(height: 16),
                const Text('庫存管理系統', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                if (state.loading) const CircularProgressIndicator(),
                if (state.loadError != null) ...[
                  Text(state.loadError!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                ],
                if (!state.loading) ...[
                  if (!_showSheetsForm) ...[
                    const Text('請選擇作為資料庫的 Excel 檔案 (.xlsx)', style: TextStyle(color: Colors.grey)),
                    if (kIsWeb)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          '選本機檔案的話，網頁版每次修改會下載一份新檔案，需自行覆蓋原檔',
                          style: TextStyle(color: Colors.orange, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('選擇 Excel 檔案'),
                    ),
                    if (kIsWeb) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('或', style: TextStyle(color: Colors.grey)),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _showSheetsForm = true),
                        icon: const Icon(Icons.cloud_outlined),
                        label: const Text('連接 Google 試算表'),
                      ),
                    ],
                  ] else ...[
                    const Text(
                      '連接 Google 試算表',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 4, bottom: 16),
                      child: Text(
                        '存檔會自動同步，不用每次下載檔案再覆蓋',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                    SizedBox(
                      width: 360,
                      child: TextField(
                        controller: _urlCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Apps Script 網頁應用程式網址',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 360,
                      child: TextField(
                        controller: _keyCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: '密鑰（SECRET_KEY）',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _showSheetsForm = false),
                          child: const Text('返回'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _connectSheets,
                          icon: const Icon(Icons.cloud_done_outlined),
                          label: const Text('連接'),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
