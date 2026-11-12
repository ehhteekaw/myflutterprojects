import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import 'login_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _ipController = TextEditingController(text: 'localhost:9090');
  List<dynamic> _shops = [];
  int? _selectedShopId;

  bool _isConnecting = false;
  bool _isConnected = false;

  // Error စာသားလေး သိမ်းဖို့ variable အသစ်
  String? _errorMessage;

  Future<void> _connectToServer() async {
    // အရင်က error ရှိရင် ရှင်းမယ်
    setState(() {
      _errorMessage = null;
      _isConnecting = true;
    });

    try {
      await ApiService.saveBaseUrl(_ipController.text.trim());
      final shops = await ApiService().getShops();

      setState(() {
        _shops = shops;
        _isConnected = true;
        _isConnecting = false;
      });
    } catch (e) {
      // Error တက်ရင် SnackBar မပြတော့ဘဲ _errorMessage ထဲကို ထည့်မယ်
      setState(() {
        _isConnecting = false;
        _errorMessage = 'Can\'t connect to the server. Please check the IP.';
      });
    }
  }

  Future<void> _saveShop() async {
    if (_selectedShopId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('shop_id', _selectedShopId!);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Device Setup')),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: SizedBox(
              width: 350,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ---- အဆင့် ၁ - IP ထည့်ရန် ----
                  const Icon(Icons.wifi, size: 50, color: Colors.blue),
                  const SizedBox(height: 10),
                  const Text(
                    'Enter Server IP Address',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _ipController,
                    decoration: InputDecoration(
                      labelText: 'Server IP',
                      hintText: 'e.g., 192.168.1.100:9090',
                      border: const OutlineInputBorder(),
                      // Error ရှိရင် TextField အောက်မှာ အနီရောင်စာသား ပေါ်စေမယ်
                      errorText: _errorMessage,
                    ),
                    enabled: !_isConnected,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isConnecting
                          ? null
                          : (_isConnected ? null : _connectToServer),
                      child: _isConnecting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _isConnected ? 'Connected!' : 'Connect to Server',
                            ),
                    ),
                  ),

                  // ---- အဆင့် ၂ - Shop ရွေးရန် ----
                  if (_isConnected) ...[
                    const Divider(height: 40),
                    const Text(
                      'Select Shop',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedShopId,
                      hint: const Text('Choose Shop'),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: _shops.map((s) {
                        return DropdownMenuItem<int>(
                          value: s['id'],
                          child: Text(s['shop_name'] ?? 'Unknown Shop'),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedShopId = val),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        onPressed: _selectedShopId == null ? null : _saveShop,
                        child: const Text(
                          'Save & Continue',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _isConnected = false;
                        _errorMessage = null;
                      }),
                      child: const Text('Change IP Address'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
