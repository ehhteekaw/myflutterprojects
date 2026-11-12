import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LocalImageService {
  /// Returns the local directory where product images are saved
  static Future<Directory> get _imageDir async {
    final docsDir = await getApplicationDocumentsDirectory();
    final imageFolder = Directory(p.join(docsDir.path, 'pos_system', 'product_images'));
    if (!await imageFolder.exists()) {
      await imageFolder.create(recursive: true);
    }
    return imageFolder;
  }

  /// Copies a picked image file to the local app folder and returns the new local path
  static Future<String> saveImageLocally(File sourceFile) async {
    final dir = await _imageDir;
    final extension = p.extension(sourceFile.path);
    final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}$extension';
    final savedFile = await sourceFile.copy(p.join(dir.path, fileName));
    return savedFile.path;
  }
}