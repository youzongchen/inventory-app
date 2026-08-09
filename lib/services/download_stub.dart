import 'dart:typed_data';

/// No-op on non-web platforms - they save via a real file path instead.
void downloadBytes(Uint8List bytes, String filename) {}
