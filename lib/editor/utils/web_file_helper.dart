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
  /// Features an auto-detecting background stripper (strips white/light or transparent backgrounds).
  static Future<Set<String>> parsePngToGridMask(Uint8List pngBytes, int gridSize) async {
    final completer = Completer<Set<String>>();
    final base64Str = base64Encode(pngBytes);
    final dataUrl = 'data:image/png;base64,$base64Str';

    final img = html.ImageElement();
    img.src = dataUrl;
    // img.onLoad never fires for a malformed/corrupt PNG - the browser
    // fires onError instead. Without racing both, a bad file hangs this
    // await forever (no exception for the caller's try/catch to catch).
    await Future.any([
      img.onLoad.first,
      img.onError.first.then((_) =>
          throw const FormatException('Image failed to load (malformed or unsupported PNG)')),
    ]).timeout(const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException(
            'Image load timed out after 10s', const Duration(seconds: 10)));

    final width = img.width ?? 100;
    final height = img.height ?? 100;

    final canvas = html.CanvasElement(width: width, height: height);
    final ctx = canvas.context2D;
    ctx.drawImage(img, 0, 0);

    final imgData = ctx.getImageData(0, 0, width, height);
    final pixels = imgData.data;

    // Detect background type from corner pixels
    final cornerIndices = [
      0, // top-left
      (width - 1) * 4, // top-right
      ((height - 1) * width) * 4, // bottom-left
      ((height - 1) * width + (width - 1)) * 4, // bottom-right
    ];

    double cornerLuminanceSum = 0;
    int cornerCount = 0;

    for (final idx in cornerIndices) {
      if (idx + 3 < pixels.length) {
        final a = pixels[idx + 3];
        if (a > 20) {
          final r = pixels[idx];
          final g = pixels[idx + 1];
          final b = pixels[idx + 2];
          final lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
          cornerLuminanceSum += lum;
          cornerCount++;
        }
      }
    }

    final isLightBackground = cornerCount == 0 || (cornerLuminanceSum / cornerCount) > 0.5;

    final mask = <String>{};
    final cellW = width / gridSize;
    final cellH = height / gridSize;

    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        final startX = (c * cellW).floor();
        final startY = (r * cellH).floor();
        final endX = ((c + 1) * cellW).floor().clamp(0, width);
        final endY = ((r + 1) * cellH).floor().clamp(0, height);

        int shapePixelCount = 0;
        int totalPixelCount = 0;

        for (int y = startY; y < endY; y++) {
          for (int x = startX; x < endX; x++) {
            final idx = (y * width + x) * 4;
            final alpha = pixels[idx + 3];
            final rVal = pixels[idx];
            final gVal = pixels[idx + 1];
            final bVal = pixels[idx + 2];

            totalPixelCount++;

            if (alpha < 20) {
              // Transparent pixel -> background
              continue;
            }

            final lum = (0.299 * rVal + 0.587 * gVal + 0.114 * bVal) / 255.0;

            if (isLightBackground) {
              // Light background: shape pixels are darker/colored pixels
              if (lum < 0.85 || (rVal < 230 || gVal < 230 || bVal < 230)) {
                shapePixelCount++;
              }
            } else {
              // Dark background: shape pixels are brighter/colored pixels
              if (lum > 0.2 || (rVal > 30 || gVal > 30 || bVal > 30)) {
                shapePixelCount++;
              }
            }
          }
        }

        if (totalPixelCount > 0 && (shapePixelCount / totalPixelCount) >= 0.20) {
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
