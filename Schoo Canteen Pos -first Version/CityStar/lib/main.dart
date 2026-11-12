import 'package:citystar/provider/cart_provider.dart';
import 'package:citystar/screens/login_screen.dart';
import 'package:citystar/screens/setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // App မစခင် သိမ်းထားတဲ့ IP ကို အရင်ယူမယ်
  await ApiService.loadBaseUrl();

  runApp(
    ChangeNotifierProvider(create: (_) => CartProvider(), child: const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: FutureBuilder<SharedPreferences>(
        future: SharedPreferences.getInstance(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final prefs = snapshot.data!;
          final shopId = prefs.getInt('shop_id');
          final serverIp = prefs.getString('server_ip'); // IP ရှိမရှိ စစ်မယ်

          // IP ရော Shop ရော မရှိသေးရင် Setup ကို ပို့မယ်။ ရှိပြီးသားဆိုရင် Login ကို ပို့မယ်။
          if (shopId == null || serverIp == null) {
            return const SetupScreen();
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}
