import 'package:drift/drift.dart';
import 'database_connection.dart'; // <--- Imports the conditional bridge

part 'database.g.dart';

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()(); // e.g., Food, Beverages
  TextColumn get description => text().nullable()();
}

class Subcategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId =>
      integer().references(Categories, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()(); // e.g., Cold Drinks, Fast Food
}

// 1. Products Table (Inventory)
class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get sku => text().unique()();
  RealColumn get price => real()();
  IntColumn get stockQuantity => integer().withDefault(const Constant(0))();
  TextColumn get category => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  IntColumn get subcategoryId => integer()
      .nullable()
      .references(Subcategories, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

// 2. Orders Table (Transactions)
class Orders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get orderNumber => text().unique()();
  RealColumn get totalPrice => real()();
  TextColumn get paymentMethod => text()();
  TextColumn get status => text()();
  IntColumn get userId => integer()
      .nullable()
      .references(Users, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get createdAt => dateTime()();
}

class OrderItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderId =>
      integer().references(Orders, #id, onDelete: KeyAction.cascade)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get quantity => integer()();
  RealColumn get unitPrice => real()();
}

// 3. Users Table (Authentication & User Roles)
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get username => text().unique()();
  TextColumn get pinCode =>
      text()(); // Standard 4-6 digit PIN for fast cashier login
  TextColumn get role =>
      text().withDefault(const Constant('Cashier'))(); // 'Admin' or 'Cashier'
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
}

class Students extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get studentIdNumber =>
      text().unique()(); // Card ID / Student ID (e.g., STU-1001)
  TextColumn get name => text()(); // Student Name
  TextColumn get gradeOrClass =>
      text().nullable()(); // Class / Grade (e.g., Grade 10)
  RealColumn get balance =>
      real().withDefault(const Constant(0.0))(); // Card Balance (MMK)
  DateTimeColumn get createdAt => dateTime().nullable()();
}

// 4. Database Setup
@DriftDatabase(tables: [
  Products,
  Orders,
  Users,
  OrderItems,
  Categories,
  Subcategories,
  Students
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  @override
  int get schemaVersion => 7; // 👉 6 မှ 7 သို့ ပြင်ဆင်ထားသည်

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(users);
        }
        if (from < 3) {
          await m.addColumn(products, products.imageUrl);
        }
        if (from < 4) {
          await m.createTable(orderItems);
        }
        if (from < 5) {
          await m.addColumn(orders, orders.userId);
        }
        if (from < 6) {
          await m.createTable(categories);
          await m.createTable(subcategories);
          await m.addColumn(products, products.subcategoryId);
        }
        if (from < 7) {
          await m.createTable(
              students); // 👉 Version 7 တွင် students table အသစ်ဆောက်ရန်
        }
      },
    );
  }
}

// 5. Database Helper Queries
extension DatabaseQueries on AppDatabase {
  // Product Queries
  Stream<List<Product>> watchAllProducts() => select(products).watch();
  Future<int> insertProduct(ProductsCompanion product) =>
      into(products).insert(product);

  // Order Queries
  Future<int> createOrder(OrdersCompanion order) => into(orders).insert(order);

  // User & Auth Queries
  Stream<List<User>> watchAllUsers() => select(users).watch();

  Future<User?> authenticateUser(String username, String pinCode) {
    return (select(users)
          ..where((u) =>
              u.username.equals(username) &
              u.pinCode.equals(pinCode) &
              u.isActive.equals(true)))
        .getSingleOrNull();
  }

  Future<int> insertUser(UsersCompanion user) => into(users).insert(user);

  // 👉 Student / ID Card Queries
  Stream<List<Student>> watchAllStudents() => select(students).watch();

  Future<Student?> getStudentByCardId(String cardId) {
    return (select(students)..where((s) => s.studentIdNumber.equals(cardId)))
        .getSingleOrNull();
  }
}
