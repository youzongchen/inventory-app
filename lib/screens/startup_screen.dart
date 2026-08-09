import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/inventory_state.dart';
import 'home_screen.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final state = context.read<InventoryState>();
    final lastPath = await state.restoreLastPath();
    if (lastPath != null) {
      await state.loadFile(lastPath);
      if (state.loadError == null && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
        return;
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickFile() async {
    final state = context.read<InventoryState>();
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      dialogTitle: '選擇庫存 Excel 檔案 (.xlsx)',
    );
    if (result == null || result.files.single.path == null) return;
    await state.loadFile(result.files.single.path!);
    if (state.loadError == null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<InventoryState>();
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inventory_2_outlined, size: 72, color: Color(0xFF2F5597)),
              const SizedBox(height: 16),
              const Text('庫存管理系統', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('請選擇作為資料庫的 Excel 檔案 (.xlsx)', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              if (state.loading) const CircularProgressIndicator(),
              if (state.loadError != null) ...[
                Text(state.loadError!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
              ],
              if (!state.loading)
                FilledButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('選擇 Excel 檔案'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
