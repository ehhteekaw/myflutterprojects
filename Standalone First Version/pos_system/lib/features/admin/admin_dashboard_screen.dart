import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/admin/student_management_screen.dart';
import '../auth/auth_provider.dart';
import '../checkout/pos_screen.dart';
import '../reports/reports_dashboard_screen.dart';
import 'product_management_screen.dart';
import 'user_management_screen.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Maverick-Canteen POS'),
        actions: [
          IconButton(
            style: IconButton.styleFrom(
              enabledMouseCursor: SystemMouseCursors.click,
              disabledMouseCursor: SystemMouseCursors.forbidden,
            ),
            icon: Row(
              children: [
                Text(
                  "${user?.username}",
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                const Icon(Icons.exit_to_app, color: Colors.red),
              ],
            ),
            tooltip: 'Logout',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirm Logout'),
                  content: const Text(
                      'Are you sure you want to log out of the terminal?'),
                  actions: [
                    TextButton(
                      style: TextButton.styleFrom(
                        enabledMouseCursor: SystemMouseCursors.click,
                        disabledMouseCursor: SystemMouseCursors.forbidden,
                      ),
                      onPressed: () => Navigator.pop(context), // Cancel
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          enabledMouseCursor: SystemMouseCursors.click,
                          disabledMouseCursor: SystemMouseCursors.forbidden,
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white),
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        ref.read(authProvider.notifier).logout();
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      },
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          children: [
            _DashboardCard(
              title: 'Sales Reports & Analytics',
              icon: Icons.bar_chart,
              color: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ReportsDashboardScreen()),
                );
              },
            ),
            _DashboardCard(
              title: 'Launch POS Terminal',
              icon: Icons.point_of_sale,
              color: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PosScreen()),
                );
              },
            ),
            _DashboardCard(
              title: 'Manage Products (Inventory)',
              icon: Icons.fastfood,
              color: Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ProductManagementScreen()),
                );
              },
            ),
            _DashboardCard(
              title: 'Manage Staff Users & Roles',
              icon: Icons.people,
              color: Colors.purple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const UserManagementScreen()),
                );
              },
            ),
            _DashboardCard(
                title: 'Manage Student',
                icon: Icons.person_2,
                color: Colors.green,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const StudentManagementScreen()),
                  );
                })
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DashboardCard(
      {required this.title,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 64, color: color),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
