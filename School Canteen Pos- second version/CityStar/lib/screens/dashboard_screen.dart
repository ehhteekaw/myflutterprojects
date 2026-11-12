import 'package:citystar/screens/pos_screen.dart';
import 'package:citystar/screens/setup_screen.dart';
import 'package:citystar/screens/shop_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Add the import for the TopUpDialog (Make sure this path matches your folder structure)
import 'package:citystar/widgets/topup_dialog.dart';

import 'customer_screen.dart';
import 'inventory.dart';
import 'manage_user_screen.dart';
import 'order_history_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String role = '';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then(
      (p) => setState(() => role = p.getString('role') ?? ''),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clears everything
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SetupScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Role: $role'),
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 3,
        padding: const EdgeInsets.all(
          16,
        ), // Added padding so it doesn't touch the edges
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          // 1. POS (Everyone)
          _card(
            'POS',
            Icons.point_of_sale,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PosScreen()),
            ),
          ),

          // 2. Top Up / Withdraw Card (Everyone - especially Cashiers)
          _card('Top Up Card', Icons.add_card, () {
            showDialog(context: context, builder: (_) => const TopUpDialog());
          }),

          // 3. Manage Products (ShopAdmin & SuperAdmin)
          if (role == 'SuperAdmin' || role == 'ShopAdmin')
            _card(
              'Manage Products',
              Icons.inventory,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const InventoryScreen(),
                ), // <--- ဒီလို ချိတ်ပါ
              ),
            ),

          // 4. Manage Users (SuperAdmin only)
          if (role == 'SuperAdmin')
            _card(
              'Manage Users',
              Icons.admin_panel_settings,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageUsersScreen()),
              ),
            ),

          if (role == 'SuperAdmin')
            _card(
              'Manage Customers',
              Icons.people,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomerScreen()),
              ),
            ),
          // SuperAdmin ပဲ မြင်ရမယ်
          if (role == 'SuperAdmin')
            _card(
              'Manage Shops',
              Icons.storefront,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShopScreen()),
              ),
            ),
          // Order History (SuperAdmin & ShopAdmin အတွက်)
          if (role == 'SuperAdmin' || role == 'ShopAdmin')
            _card(
              'Order History',
              Icons.history,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card(String title, IconData icon, VoidCallback tap) {
    return Card(
      elevation: 4, // Added a little shadow to look nicer
      child: InkWell(
        onTap: tap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: Colors.blue), // Made the icon blue
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
