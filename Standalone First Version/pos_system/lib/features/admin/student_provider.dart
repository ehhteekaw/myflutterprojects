import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../core/database.dart';
import 'product_provider.dart';

// Stream All Students
final studentStreamProvider = StreamProvider.autoDispose<List<Student>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllStudents();
});

// Search Query State for Students
final studentSearchQueryProvider = StateProvider<String>((ref) => '');
