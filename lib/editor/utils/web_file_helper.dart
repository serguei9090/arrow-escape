import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class WebFileHelper {
  WebFileHelper._();

  /// Triggers a browser file download for the given byte array.
  static void downloadBytes(Uint8List bytes, String filename) {
    final blob = html.Blob([bytes], 'application/octet-stream');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  /// Opens a browser file picker to select a single file matching [accept].
  static Future<Uint8List?> pickFileBytes({String accept = '.bin'}) async {
    final uploadInput = html.FileUploadInputElement();
    uploadInput.accept = accept;
    uploadInput.click();

    await uploadInput.onChange.first;
    if (uploadInput.files == null || uploadInput.files!.isEmpty) {
      return null;
    }

    final file = uploadInput.files!.first;
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoadEnd.first;

    final result = reader.result;
    if (result is Uint8List) {
      return result;
    } else if (result is ByteBuffer) {
      return result.asUint8List();
    }
    return null;
  }

  /// Opens a browser file picker to select multiple files.
  static Future<List<NamedBytes>> pickMultipleFiles({String accept = 'image/png'}) async {
    final uploadInput = html.FileUploadInputElement()
      ..accept = accept
      ..multiple = true;
    uploadInput.click();

    await uploadInput.onChange.first;
    if (uploadInput.files == null || uploadInput.files!.isEmpty) {
      return [];
    }

    final results = <NamedBytes>[];
    for (final file in uploadInput.files!) {
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoadEnd.first;
      final res = reader.result;
      Uint8List? bytes;
      if (res is Uint8List) {
        bytes = res;
      } else if (res is ByteBuffer) {
        bytes = res.asUint8List();
      }
      if (bytes != null) {
        results.add(NamedBytes(name: file.name, bytes: bytes));
      }
    }
    return results;
  }

  /// Convert PNG image bytes into a grid mask Set<String> ('row,col') for a given [gridSize].
  static Future<Set<String>> parsePngToGridMask(Uint8List pngBytes, int gridSize) async {
    final completer = Completer<Set<String>>();
    final base64Str = base64Encode(pngBytes);
    final dataUrl = 'data:image/png;base64,$base64Str';

    final img = html.ImageElement();
    img.src = dataUrl;
    await img.onLoad.first;

    final canvas = html.CanvasElement(width: img.width, height: img.height);
    final ctx = canvas.context2D;
    ctx.drawImage(img, 0, 0);

    final imgData = ctx.getImageData(0, 0, img.width!, img.height!);
    final pixels = imgData.data;

    final mask = <String>{};
    final cellW = img.width! / gridSize;
    final cellH = img.height! / gridSize;

    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        final startX = (c * cellW).floor();
        final startY = (r * cellH).floor();
        final endX = ((c + 1) * cellW).floor().clamp(0, img.width!);
        final endY = ((r + 1) * cellH).floor().clamp(0, img.height!);

        int solidPixelCount = 0;
        int totalPixelCount = 0;

        for (int y = startY; y < endY; y++) {
          for (int x = startX; x < endX; x++) {
            final idx = (y * img.width! + x) * 4;
            final alpha = pixels[idx + 3];
            final rVal = pixels[idx];
            final gVal = pixels[idx + 1];
            final bVal = pixels[idx + 2];

            totalPixelCount++;
            // Active if non-transparent and not pure white (e.g. dark or colored shape)
            final isDarkOrColor = (rVal < 240 || gVal < 240 || bVal < 240);
            if (alpha > 50 && isDarkOrColor) {
              solidPixelCount++;
            }
          }
        }

        if (totalPixelCount > 0 && (solidPixelCount / totalPixelCount) >= 0.25) {
          mask.add('$r,$c');
        }
      }
    }

    completer.complete(mask);
    return completer.future;
  }
}

class NamedBytes {
  final String name;
  final Uint8List bytes;
  NamedBytes({required this.name, required this.bytes});
}
