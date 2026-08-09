// This file only compiles into the web build (see download.dart's
// conditional export), so dart:html is the right tool here despite the
// general "avoid web libraries" lint aimed at cross-platform Flutter code.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:typed_data';
import 'dart:html' as html;

/// Triggers a browser download of [bytes] as [filename]. Web has no concept
/// of "save back to the same file path" - the user re-downloads a fresh copy
/// each time and replaces the original.
void downloadBytes(Uint8List bytes, String filename) {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
