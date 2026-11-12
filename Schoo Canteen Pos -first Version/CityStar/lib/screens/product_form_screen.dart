import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';
import '../services/api_service.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product;
  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  List<dynamic> _categories = [];
  List<dynamic> _subcategories = [];
  int? _selectedCategoryId;
  int? _selectedSubcategoryId;

  File? _selectedImage;
  String? _existingImageUrl;
  bool _isLoading = false;

  bool get isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _nameCtrl.text = widget.product!.name;
      _skuCtrl.text = widget.product!.sku;
      _priceCtrl.text = widget.product!.price.toString();
      _existingImageUrl = widget.product!.imageUrl;
      _selectedSubcategoryId = widget.product!.subcategoryId;
    }
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await ApiService().getCategories();
    setState(() {
      _categories = cats;
    });
    // တကယ်လို့ Edit လုပ်တာဖြစ်ပြီး Subcategory ရွေးထားရင် Category ကို ရှာမယ်
    if (_selectedSubcategoryId != null) {
      for (var cat in _categories) {
        final subs = await ApiService().getSubcategories(cat['id']);
        if (subs.any((s) => s['id'] == _selectedSubcategoryId)) {
          setState(() {
            _selectedCategoryId = cat['id'];
            _subcategories = subs;
          });
          break;
        }
      }
    }
  }

  Future<void> _loadSubcategories(int categoryId) async {
    final subs = await ApiService().getSubcategories(categoryId);
    setState(() {
      _subcategories = subs;
      _selectedSubcategoryId = null; // Category ပြောင်းရင် Sub ကို ရှင်းမယ်
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      String? finalImageUrl = _existingImageUrl;

      // ၁။ Image အသစ် ရွေးထားရင် အရင်တင်မယ်
      if (_selectedImage != null) {
        final uploadedUrl = await ApiService().uploadImage(_selectedImage!);
        if (uploadedUrl == null) {
          throw Exception('Image upload failed');
        }
        finalImageUrl = uploadedUrl;
      }

      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getInt('shop_id') ?? 1;

      final name = _nameCtrl.text.trim();
      final sku = _skuCtrl.text.trim();
      final price = double.parse(_priceCtrl.text.trim());

      bool success;
      if (isEditing) {
        success = await ApiService().updateProduct(
          widget.product!.id,
          name,
          sku,
          price,
          finalImageUrl,
          _selectedSubcategoryId,
        );
      } else {
        success = await ApiService().addProduct(
          name,
          sku,
          price,
          shopId,
          finalImageUrl,
          _selectedSubcategoryId,
        );
      }

      if (!mounted) return;

      if (success) {
        Navigator.pop(context, true); // အောင်မြင်ရင် true ပြန်ပို့မယ်
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to save product')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Product' : 'Add Product')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- Image Picker ----
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: _selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : _existingImageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              // ApiService.baseUrl က 'http://localhost:9090' ဖြစ်ရမယ်။
                              // _existingImageUrl က '/uploads/123.jpg' ဖြစ်ရမယ်။
                              '${ApiService.baseUrl}$_existingImageUrl',
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.broken_image),
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  },
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.add_a_photo,
                                size: 40,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Select Image',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ---- Name ----
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Product Name',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Enter product name' : null,
              ),
              const SizedBox(height: 12),

              // ---- SKU ----
              TextFormField(
                controller: _skuCtrl,
                decoration: const InputDecoration(
                  labelText: 'SKU (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // ---- Price ----
              TextFormField(
                controller: _priceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Price (MMK)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Enter price';
                  if (double.tryParse(val) == null) return 'Invalid number';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // ---- Category Dropdown ----
              DropdownButtonFormField<int>(
                initialValue: _selectedCategoryId,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((cat) {
                  return DropdownMenuItem<int>(
                    value: cat['id'],
                    child: Text(cat['name']),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedCategoryId = val);
                  if (val != null) _loadSubcategories(val);
                },
              ),
              const SizedBox(height: 12),

              // ---- Subcategory Dropdown ----
              DropdownButtonFormField<int>(
                initialValue: _selectedSubcategoryId,
                decoration: const InputDecoration(
                  labelText: 'Subcategory',
                  border: OutlineInputBorder(),
                ),
                items: _subcategories.map((sub) {
                  return DropdownMenuItem<int>(
                    value: sub['id'],
                    child: Text(sub['name']),
                  );
                }).toList(),
                onChanged: (val) =>
                    setState(() => _selectedSubcategoryId = val),
              ),
              const SizedBox(height: 24),

              // ---- Save Button ----
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProduct,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          isEditing ? 'Update Product' : 'Save Product',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
