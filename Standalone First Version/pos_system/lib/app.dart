import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/checkout/pos_screen.dart';
import 'features/admin/admin_dashboard_screen.dart'; // We will create this next

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'School Canteen POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: authState.currentUser == null
          ? const LoginScreen()
          : authState.currentUser!.role == 'Admin'
          ? const AdminDashboardScreen() // Admins get management & POS access
          : const PosScreen(),         // Cashiers go directly to POS terminal
    );
  }
}