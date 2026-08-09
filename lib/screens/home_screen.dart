import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/inventory_state.dart';
import 'location_screen.dart';
import 'dashboard_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<InventoryState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('庫存管理系統'),
        actions: [
          IconButton(
            tooltip: '切換 Excel 檔案',
            icon: const Icon(Icons.swap_horiz),
            onPressed: () => context.read<InventoryState>().pickAndLoadFile(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (state.filePath != null || state.webFileName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: InkWell(
                    onTap: () => context.read<InventoryState>().pickAndLoadFile(),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              '資料來源：${state.filePath ?? state.webFileName}',
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.edit, size: 14, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),
              Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: [
                  _HomeCard(
                    icon: Icons.move_to_inbox,
                    label: '進貨',
                    color: const Color(0xFF2E7D32),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LocationScreen(mode: 'in')),
                    ),
                  ),
                  _HomeCard(
                    icon: Icons.outbox,
                    label: '出貨',
                    color: const Color(0xFFC62828),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LocationScreen(mode: 'out')),
                    ),
                  ),
                  _HomeCard(
                    icon: Icons.bar_chart,
                    label: '庫存管理',
                    color: const Color(0xFF2F5597),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DashboardScreen()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _HomeCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 64, color: color),
              const SizedBox(height: 16),
              Text(label, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
