import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database.dart';
import '../admin/product_provider.dart';
import '../checkout/pos_provider.dart';

class AuthState {
  final User? currentUser;
  final bool isLoading;

  AuthState({this.currentUser, this.isLoading = false});
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AppDatabase _db;
  final Ref _ref;
  AuthNotifier(this._db, this._ref) : super(AuthState());

  /// Automatically creates default users if the table is empty
  Future<void> seedDefaultUsersIfNeeded() async {
    final usersList = await _db.select(_db.users).get();
    if (usersList.isEmpty) {
      await _db.into(_db.users).insert(
            UsersCompanion.insert(
              username: 'admin',
              pinCode: '1234',
              role: const Value('Admin'),
              createdAt: DateTime.now(), // <-- Required field added
            ),
          );
      await _db.into(_db.users).insert(
            UsersCompanion.insert(
              username: 'cashier1',
              pinCode: '0000',
              role: const Value('Cashier'),
              createdAt: DateTime.now(), // <-- Required field added
            ),
          );
    }
  }

  // Login via Username & PIN
  Future<bool> loginWithPin(String username, String pinCode) async {
    state = AuthState(isLoading: true);

    // 1. Ensure default users exist before authenticating
    await seedDefaultUsersIfNeeded();

    // 2. Query user with correct Drift condition syntax using bitwise & or chained filters
    // Query user by chaining separate .where() clauses
    final user = await (_db.select(_db.users)
          ..where((u) => u.username.equals(username))
          ..where((u) => u.pinCode.equals(pinCode))
          ..where((u) => u.isActive.equals(true)))
        .getSingleOrNull();

    if (user != null) {
      state = AuthState(currentUser: user, isLoading: false);
      return true;
    } else {
      state = AuthState(currentUser: null, isLoading: false);
      return false;
    }
  }

  void logout() {
    state = AuthState(currentUser: null);
    _ref.read(cartProvider.notifier).clearCart();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final db = ref.watch(databaseProvider);
  return AuthNotifier(db, ref);
});
