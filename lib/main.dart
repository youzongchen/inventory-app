import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'state/inventory_state.dart';
import 'screens/startup_screen.dart';

void main() {
  runApp(const InventoryApp());
}

class InventoryApp extends StatelessWidget {
  const InventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => InventoryState(),
      child: MaterialApp(
        title: '庫存管理',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF2F5597),
          useMaterial3: true,
        ),
        home: const StartupScreen(),
      ),
    );
  }
}
