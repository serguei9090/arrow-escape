import 'dart:typed_data';

class PngMaskModel {
  final String id;
  final String filename;
  final String subfolder; // e.g. '10x10', '15x15', '25x25', '30x30', '40x40'
  final Uint8List imageBytes;
  final int gridSize;
  final Set<String> mask; // 'row,col'

  PngMaskModel({
    required this.id,
    required this.filename,
    required this.subfolder,
    required this.imageBytes,
    required this.gridSize,
    required this.mask,
  });

  PngMaskModel copyWith({
    String? id,
    String? filename,
    String? subfolder,
    Uint8List? imageBytes,
    int? gridSize,
    Set<String>? mask,
  }) {
    return PngMaskModel(
      id: id ?? this.id,
      filename: filename ?? this.filename,
      subfolder: subfolder ?? this.subfolder,
      imageBytes: imageBytes ?? this.imageBytes,
      gridSize: gridSize ?? this.gridSize,
      mask: mask ?? Set.from(this.mask),
    );
  }
}
