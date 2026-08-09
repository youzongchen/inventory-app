import 'package:flutter/material.dart';
import '../models.dart';
import 'scan_screen.dart';

class LocationScreen extends StatelessWidget {
  final String mode; // 'in' or 'out'
  const LocationScreen({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    final title = mode == 'in' ? '進貨' : '出貨';
    return Scaffold(
      appBar: AppBar(title: Text('$title - 選擇地點')),
      body: Center(
        child: Wrap(
          spacing: 24,
          runSpacing: 24,
          alignment: WrapAlignment.center,
          children: kLocations
              .map((loc) => _LocationCard(
                    label: loc,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ScanScreen(mode: mode, location: loc),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LocationCard({required this.label, required this.onTap});

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
          width: 220,
          height: 160,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2F5597).withValues(alpha: 0.3), width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(label == '家裡' ? Icons.home : Icons.apartment, size: 48, color: const Color(0xFF2F5597)),
              const SizedBox(height: 12),
              Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
