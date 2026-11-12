import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../models/user.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});
  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  Future<List<User>>? _usersFuture; // late ကို ဖျက်ပြီး ? လုပ်ပါ
  String _currentRole = '';
  int? _currentShopId;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _currentRole = prefs.getString('role') ?? 'Cashier';
    _currentShopId = prefs.getInt('shop_id');

    setState(() {
      // SuperAdmin ဆိုရင် အကုန်ယူမယ်၊ မဟုတ်ရင် သူ့ဆိုင်ထဲကပဲ ယူမယ်
      final shopIdToFetch = _currentRole == 'SuperAdmin'
          ? null
          : _currentShopId;

      _usersFuture = ApiService().getUsers(shopIdToFetch).then((data) {
        return data.map((e) => User.fromJson(e)).toList();
      });
    });
  }

  // Add / Edit Dialog
  void _showUserFormDialog({User? user}) {
    final usernameCtrl = TextEditingController(text: user?.username);
    final pinCtrl = TextEditingController();
    String role = user?.role ?? 'Cashier';
    bool isActive = user?.isActive ?? true;
    final isEditing = user != null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEditing ? 'Edit User' : 'Add New User'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: usernameCtrl,
                    decoration: const InputDecoration(labelText: 'Username'),
                  ),
                  if (!isEditing) // PIN ကို အသစ်ထည့်တဲ့အခါပဲ ပြမယ် (Edit မှာ PIN ပြင်လို့မရအောင်)
                    TextField(
                      controller: pinCtrl,
                      decoration: const InputDecoration(labelText: 'PIN Code'),
                    ),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    items: ['SuperAdmin', 'ShopAdmin', 'Cashier']
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (val) => setDialogState(() => role = val!),
                    decoration: const InputDecoration(labelText: 'Role'),
                  ),
                  if (isEditing)
                    SwitchListTile(
                      title: const Text('Active'),
                      value: isActive,
                      onChanged: (val) => setDialogState(() => isActive = val),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  bool success;
                  if (isEditing) {
                    success = await ApiService().updateUser(
                      user.id,
                      usernameCtrl.text.trim(),
                      role,
                      isActive ? 1 : 0,
                    );
                  } else {
                    final shopId = role == 'SuperAdmin' ? null : _currentShopId;
                    success = await ApiService().addUser(
                      shopId,
                      usernameCtrl.text.trim(),
                      pinCtrl.text.trim(),
                      role,
                    );
                  }

                  if (success && mounted) {
                    Navigator.pop(context);
                    _loadUserData();
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Operation failed. Username might exist.',
                        ),
                      ),
                    );
                  }
                },
                child: Text(isEditing ? 'Update' : 'Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Delete Confirm
  void _deleteUser(int id, String username) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User?'),
        content: Text('Are you sure you want to delete $username?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ApiService().deleteUser(id);
              if (success && mounted) _loadUserData();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Users')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUserFormDialog(),
        child: const Icon(Icons.person_add),
      ),
      body: FutureBuilder<List<User>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (_usersFuture == null ||
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No users found.'));
          }

          final users = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final u = users[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: u.role == 'SuperAdmin'
                        ? Colors.red[100]
                        : u.role == 'ShopAdmin'
                        ? Colors.orange[100]
                        : Colors.blue[100],
                    child: Icon(
                      u.role == 'SuperAdmin' ? Icons.security : Icons.person,
                      color: u.role == 'SuperAdmin'
                          ? Colors.red
                          : u.role == 'ShopAdmin'
                          ? Colors.orange
                          : Colors.blue,
                    ),
                  ),
                  title: Text(
                    u.username,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Role: ${u.role} • ${u.isActive ? "Active" : "Inactive"}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showUserFormDialog(user: u),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteUser(u.id, u.username),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
