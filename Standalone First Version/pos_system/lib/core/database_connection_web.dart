import 'package:drift/drift.dart';
import 'package:drift/web.dart';

QueryExecutor openConnection() {
  return DatabaseConnection(
    WebDatabase('pos_web_db', logStatements: true),
  );
}