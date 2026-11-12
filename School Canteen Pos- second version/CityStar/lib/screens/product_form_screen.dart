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
    setState(() => _categories = cats);

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
      _selectedSubcategoryId = null;
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      String? finalImageUrl = _existingImageUrl;

      if (_selectedImage != null) {
        final uploadedUrl = await ApiService().uploadImage(_selectedImage!);
        if (uploadedUrl == null) throw Exception('Image upload failed');
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
        Navigator.pop(context, true);
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
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ================= TOP: Title (X ခလုတ်ရဲ့ အောက်မှာ) =================
          Padding(
            padding: const EdgeInsets.fromLTRB(
              10,
              20,
              20,
              20,
            ), // X ခလုတ်အတွက် နေရာချန်ထားတယ်
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'Edit Product' : 'Add New Product',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // ================= BOTTOM: Form =================
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
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
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: _selectedImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    _selectedImage!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : _existingImageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    _existingImageUrl!.startsWith('http')
                                        ? _existingImageUrl!
                                        : '${ApiService.baseUrl}${_existingImageUrl}',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.broken_image),
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
                    const SizedBox(height: 24),

                    // ---- Name ----
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Product Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.inventory_2),
                      ),
                      validator: (val) => val == null || val.isEmpty
                          ? 'Enter product name'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // ---- SKU ----
                    TextFormField(
                      controller: _skuCtrl,
                      decoration: InputDecoration(
                        labelText: 'SKU (Optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.qr_code),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ---- Price ----
                    TextFormField(
                      controller: _priceCtrl,
                      decoration: InputDecoration(
                        labelText: 'Price (MMK)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.attach_money),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Enter price';
                        if (double.tryParse(val) == null)
                          return 'Invalid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ---- Category Dropdown ----
                    DropdownButtonFormField<int>(
                      value: _selectedCategoryId,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.category),
                      ),
                      items: _categories
                          .map(
                            (cat) => DropdownMenuItem<int>(
                              value: cat['id'],
                              child: Text(cat['name']),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        setState(() => _selectedCategoryId = val);
                        if (val != null) _loadSubcategories(val);
                      },
                    ),
                    const SizedBox(height: 16),

                    // ---- Subcategory Dropdown ----
                    DropdownButtonFormField<int>(
                      value: _selectedSubcategoryId,
                      decoration: InputDecoration(
                        labelText: 'Subcategory',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.subdirectory_arrow_right),
                      ),
                      items: _subcategories
                          .map(
                            (sub) => DropdownMenuItem<int>(
                              value: sub['id'],
                              child: Text(sub['name']),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedSubcategoryId = val),
                    ),
                    const SizedBox(height: 32),

                    // ---- Save Button ----
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _isLoading ? null : _saveProduct,
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                isEditing ? 'Update Product' : 'Save Product',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
