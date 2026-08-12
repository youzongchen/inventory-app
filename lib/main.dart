import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'state/inventory_state.dart';
import 'screens/startup_screen.dart';

void main() {
  // WebKit's native BarcodeDetector API on iOS Safari reports formats as
  // supported but frequently fails to actually decode EAN/UPC product
  // barcodes (as opposed to QR codes) - force the WASM ZXing reader there
  // instead, since it doesn't rely on that browser API.
  if (kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    MobileScannerPlatform.instance.setWebBarcodeReader(WebBarcodeReader.zxingWasm);
  }
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
