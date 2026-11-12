import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:pos_system/features/admin/product_provider.dart';
import '../../core/database.dart';
import '../checkout/pos_provider.dart';

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);

    return Scaffold(
      appBar:
          AppBar(title: const Text('Staff & Cashier User Management (Admin)')),
      body: StreamBuilder<List<User>>(
        stream: db.watchAllUsers(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final users = snapshot.data!;

          if (users.isEmpty)
            return const Center(child: Text('No users found.'));

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      user.role == 'Admin' ? Colors.purple : Colors.blue,
                  child: Icon(
                      user.role == 'Admin'
                          ? Icons.admin_panel_settings
                          : Icons.person,
                      color: Colors.white),
                ),
                title: Text(user.username,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    'Role: ${user.role} | PIN: ${user.pinCode} | Status: ${user.isActive ? "Active" : "Disabled"}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      style: IconButton.styleFrom(
                        enabledMouseCursor: SystemMouseCursors.click,
                        disabledMouseCursor: SystemMouseCursors.forbidden,
                      ),
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () =>
                          _showUserDialog(context, db, existingUser: user),
                    ),
                    IconButton(
                      style: IconButton.styleFrom(
                        enabledMouseCursor: SystemMouseCursors.click,
                        disabledMouseCursor: SystemMouseCursors.forbidden,
                      ),
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete User Account'),
                            content: Text(
                                'Are you sure you want to delete staff account "${user.username}"?'),
                            actions: [
                              TextButton(
                                style: TextButton.styleFrom(
                                  enabledMouseCursor: SystemMouseCursors.click,
                                  disabledMouseCursor:
                                      SystemMouseCursors.forbidden,
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  enabledMouseCursor: SystemMouseCursors.click,
                                  disabledMouseCursor:
                                      SystemMouseCursors.forbidden,
                                ),
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await (db.delete(db.users)
                                        ..where((u) => u.id.equals(user.id)))
                                      .go();
                                },
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        mouseCursor: SystemMouseCursors.click,
        onPressed: () => _showUserDialog(context, db),
        label: const Text('Add User'),
        icon: const Icon(Icons.person_add),
      ),
    );
  }

  void _showUserDialog(BuildContext context, AppDatabase db,
      {User? existingUser}) {
    final usernameController =
        TextEditingController(text: existingUser?.username ?? '');
    final pinController =
        TextEditingController(text: existingUser?.pinCode ?? '');
    String selectedRole = existingUser?.role ?? 'Cashier';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existingUser == null ? 'Create New User' : 'Edit User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: 'Username')),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                    labelText: 'PIN Code', counterText: ''),
              ),
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                items: const [
                  DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'Cashier', child: Text('Cashier')),
                ],
                onChanged: (val) =>
                    setState(() => selectedRole = val ?? 'Cashier'),
                decoration: const InputDecoration(labelText: 'Role Access'),
              ),
            ],
          ),
          actions: [
            TextButton(
                style: TextButton.styleFrom(
                  enabledMouseCursor: SystemMouseCursors.click,
                  disabledMouseCursor: SystemMouseCursors.forbidden,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                enabledMouseCursor: SystemMouseCursors.click,
                disabledMouseCursor: SystemMouseCursors.forbidden,
              ),
              onPressed: () async {
                final username = usernameController.text.trim();
                final pin = pinController.text.trim();

                if (username.isNotEmpty && pin.isNotEmpty) {
                  if (existingUser == null) {
                    await db.into(db.users).insert(
                          UsersCompanion.insert(
                            username: username,
                            pinCode: pin,
                            role: Value(selectedRole),
                            createdAt: DateTime.now(),
                          ),
                        );
                  } else {
                    await (db.update(db.users)
                          ..where((u) => u.id.equals(existingUser.id)))
                        .write(
                      UsersCompanion(
                        username: Value(username),
                        pinCode: Value(pin),
                        role: Value(selectedRole),
                      ),
                    );
                  }
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
