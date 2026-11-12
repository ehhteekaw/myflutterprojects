import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:file_picker/file_picker.dart';
import '../../core/database.dart';
import '../../core/services/image_service.dart';
import 'product_provider.dart';

class ProductManagementScreen extends ConsumerStatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  ConsumerState<ProductManagementScreen> createState() =>
      _ProductManagementScreenState();
}

class _ProductManagementScreenState
    extends ConsumerState<ProductManagementScreen> {
  int? _selectedFilterCategoryId;
  int? _selectedFilterSubcategoryId;

  @override
  Widget build(BuildContext context) {
    final productsWithCatAsync = ref.watch(productsWithCategoryProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Inventory Management (Admin)'),
        elevation: 1,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                enabledMouseCursor: SystemMouseCursors.click,
                disabledMouseCursor: SystemMouseCursors.forbidden,
              ),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Manage Categories'),
              onPressed: () => _showAddCategoryModal(context, ref, db),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ================= 1. MAIN CATEGORY FILTER BAR =================
          categoriesAsync.when(
            data: (categories) {
              if (categories.isEmpty) return const SizedBox.shrink();
              return Container(
                height: 52,
                color: Colors.grey.shade50,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    FilterChip(
                      mouseCursor: SystemMouseCursors.click,
                      label: const Text('All Categories'),
                      selected: _selectedFilterCategoryId == null,
                      onSelected: (_) {
                        setState(() {
                          _selectedFilterCategoryId = null;
                          _selectedFilterSubcategoryId =
                              null; // Reset subcategory filter
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    ...categories.map((cat) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          mouseCursor: SystemMouseCursors.click,
                          label: Text(cat.name),
                          selected: _selectedFilterCategoryId == cat.id,
                          onSelected: (selected) {
                            setState(() {
                              _selectedFilterCategoryId =
                                  selected ? cat.id : null;
                              _selectedFilterSubcategoryId =
                                  null; // Reset subcategory on category change
                            });
                          },
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // ================= 2. SUBCATEGORY FILTER BAR (CASCADING) =================
          if (_selectedFilterCategoryId != null)
            Consumer(
              builder: (context, ref, child) {
                final subcategoriesAsync = ref.watch(
                    subcategoriesByCatProvider(_selectedFilterCategoryId!));

                return subcategoriesAsync.when(
                  data: (subcategories) {
                    if (subcategories.isEmpty) return const SizedBox.shrink();
                    return Container(
                      height: 44,
                      color: Colors.grey.shade100,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          FilterChip(
                            mouseCursor: SystemMouseCursors.click,
                            backgroundColor: Colors.white,
                            label: const Text('All Subcategories'),
                            selected: _selectedFilterSubcategoryId == null,
                            onSelected: (_) {
                              setState(
                                  () => _selectedFilterSubcategoryId = null);
                            },
                          ),
                          const SizedBox(width: 8),
                          ...subcategories.map((sub) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: FilterChip(
                                mouseCursor: SystemMouseCursors.click,
                                backgroundColor: Colors.white,
                                label: Text(sub.name),
                                selected:
                                    _selectedFilterSubcategoryId == sub.id,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedFilterSubcategoryId =
                                        selected ? sub.id : null;
                                  });
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),

          const Divider(height: 1),

          // ================= 3. PRODUCT DATATABLE VIEW =================
          Expanded(
            child: productsWithCatAsync.when(
              data: (items) {
                // Cascading Filter Logic: Main Category & Subcategory
                final filteredItems = items.where((item) {
                  final matchesCategory = _selectedFilterCategoryId == null ||
                      item.category?.id == _selectedFilterCategoryId;

                  final matchesSubcategory =
                      _selectedFilterSubcategoryId == null ||
                          item.subcategory?.id == _selectedFilterSubcategoryId;

                  return matchesCategory && matchesSubcategory;
                }).toList();

                if (filteredItems.isEmpty) {
                  return const Center(
                    child: Text(
                        'No products found under this category/subcategory.',
                        style: TextStyle(color: Colors.grey, fontSize: 16)),
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SizedBox(
                    width: double.infinity,
                    child: DataTable(
                      headingRowColor:
                          WidgetStateProperty.all(Colors.grey.shade100),
                      columns: const [
                        DataColumn(
                            label: Text('Image',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('Product Name',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('SKU Code',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('Category',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('Subcategory',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('Price',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('Total Sold',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple))),
                        DataColumn(
                            label: Text('Stock',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('Actions',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: filteredItems.map((item) {
                        final product = item.product;
                        final categoryName =
                            item.category?.name ?? 'Unassigned';
                        final subcategoryName = item.subcategory?.name ?? '-';

                        return DataRow(
                          cells: [
                            // Image Preview
                            DataCell(
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color: Colors.grey[200],
                                ),
                                child: product.imageUrl != null &&
                                        product.imageUrl!.isNotEmpty &&
                                        File(product.imageUrl!).existsSync()
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.file(
                                          File(product.imageUrl!),
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const Icon(Icons.fastfood,
                                        size: 22, color: Colors.grey),
                              ),
                            ),

                            // Product Name
                            DataCell(Text(product.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold))),

                            // SKU Code
                            DataCell(Text(product.sku)),

                            // Category Chip
                            DataCell(
                              Chip(
                                labelPadding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                backgroundColor: Colors.blue.shade50,
                                label: Text(
                                  categoryName,
                                  style: TextStyle(
                                      color: Colors.blue.shade800,
                                      fontSize: 12),
                                ),
                              ),
                            ),

                            // Subcategory
                            DataCell(
                              Text(subcategoryName,
                                  style:
                                      const TextStyle(color: Colors.black87)),
                            ),

                            // Price
                            DataCell(
                              Text(
                                '${product.price.toStringAsFixed(0)} MMK',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green),
                              ),
                            ),

                            // Total Sold
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${item.totalSold} units',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple.shade700),
                                ),
                              ),
                            ),

                            // Stock Quantity
                            DataCell(
                              Text(
                                '${product.stockQuantity}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: product.stockQuantity < 10
                                      ? Colors.red
                                      : Colors.black,
                                ),
                              ),
                            ),

                            // Edit / Delete Actions
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    style: IconButton.styleFrom(
                                      enabledMouseCursor:
                                          SystemMouseCursors.click,
                                      disabledMouseCursor:
                                          SystemMouseCursors.forbidden,
                                    ),
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue, size: 20),
                                    onPressed: () => _showProductDialog(
                                      context,
                                      ref,
                                      db,
                                      existingProduct: product,
                                      existingCategoryId: item.category?.id,
                                    ),
                                  ),
                                  IconButton(
                                    style: IconButton.styleFrom(
                                      enabledMouseCursor:
                                          SystemMouseCursors.click,
                                      disabledMouseCursor:
                                          SystemMouseCursors.forbidden,
                                    ),
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red, size: 20),
                                    onPressed: () => _confirmDeleteProduct(
                                        context, db, product),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        mouseCursor: SystemMouseCursors.click,
        onPressed: () => _showProductDialog(context, ref, db),
        label: const Text('Add Product'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  // ================= ADD / EDIT PRODUCT DIALOG =================
  void _showProductDialog(
    BuildContext context,
    WidgetRef ref,
    AppDatabase db, {
    Product? existingProduct,
    int? existingCategoryId,
  }) {
    final nameController =
        TextEditingController(text: existingProduct?.name ?? '');
    final skuController = TextEditingController(
        text: existingProduct?.sku ??
            'SKU-${DateTime.now().millisecondsSinceEpoch}');
    final priceController =
        TextEditingController(text: existingProduct?.price.toString() ?? '');
    final stockController = TextEditingController(
        text: existingProduct?.stockQuantity.toString() ?? '100');

    String? selectedImagePath = existingProduct?.imageUrl;
    int? selectedCategoryId = existingCategoryId;
    int? selectedSubcategoryId = existingProduct?.subcategoryId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final categoriesAsync = ref.watch(categoriesProvider);

          return AlertDialog(
            title: Text(
                existingProduct == null ? 'Add New Product' : 'Edit Product'),
            content: SizedBox(
              width: 450,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                        controller: nameController,
                        decoration:
                            const InputDecoration(labelText: 'Product Name')),
                    const SizedBox(height: 8),
                    TextField(
                        controller: skuController,
                        decoration:
                            const InputDecoration(labelText: 'SKU Code')),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                              controller: priceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'Price (MMK)')),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                              controller: stockController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'Stock Quantity')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Main Category Dropdown
                    categoriesAsync.when(
                      data: (categories) {
                        return DropdownButtonFormField<int>(
                          mouseCursor: SystemMouseCursors.click,
                          initialValue: selectedCategoryId,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          hint: const Text('Select Category'),
                          items: categories.map((cat) {
                            return DropdownMenuItem(
                              value: cat.id,
                              child: Text(cat.name),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              selectedCategoryId = val;
                              selectedSubcategoryId = null;
                            });
                          },
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('Error loading categories'),
                    ),
                    const SizedBox(height: 12),

                    // Cascading Subcategory Dropdown
                    if (selectedCategoryId != null)
                      Consumer(
                        builder: (context, ref, child) {
                          final subCategoriesAsync = ref.watch(
                              subcategoriesByCatProvider(selectedCategoryId!));

                          return subCategoriesAsync.when(
                            data: (subcategories) {
                              if (subcategories.isEmpty) {
                                return const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'No subcategories found for this category.',
                                    style: TextStyle(
                                        color: Colors.orange, fontSize: 12),
                                  ),
                                );
                              }

                              return DropdownButtonFormField<int>(
                                mouseCursor: SystemMouseCursors.click,
                                initialValue: selectedSubcategoryId,
                                decoration: const InputDecoration(
                                  labelText: 'Subcategory',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                hint: const Text('Select Subcategory'),
                                items: subcategories.map((sub) {
                                  return DropdownMenuItem(
                                    value: sub.id,
                                    child: Text(sub.name),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    selectedSubcategoryId = val;
                                  });
                                },
                              );
                            },
                            loading: () => const LinearProgressIndicator(),
                            error: (_, __) =>
                                const Text('Error loading subcategories'),
                          );
                        },
                      ),
                    if (selectedCategoryId != null) const SizedBox(height: 12),

                    // Image Picker
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey[100],
                          ),
                          child: selectedImagePath != null &&
                                  selectedImagePath!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: File(selectedImagePath!).existsSync()
                                      ? Image.file(
                                          File(selectedImagePath!),
                                          fit: BoxFit.cover,
                                        )
                                      : const Icon(Icons.broken_image,
                                          color: Colors.grey),
                                )
                              : const Icon(Icons.image, color: Colors.grey),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            enabledMouseCursor: SystemMouseCursors.click,
                            disabledMouseCursor: SystemMouseCursors.forbidden,
                          ),
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.image,
                              allowMultiple: false,
                            );

                            if (result != null &&
                                result.files.single.path != null) {
                              final pickedFile =
                                  File(result.files.single.path!);
                              final savedPath =
                                  await LocalImageService.saveImageLocally(
                                      pickedFile);

                              setState(() {
                                selectedImagePath = savedPath;
                              });
                            }
                          },
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Pick Image'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  enabledMouseCursor: SystemMouseCursors.click,
                  disabledMouseCursor: SystemMouseCursors.forbidden,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  enabledMouseCursor: SystemMouseCursors.click,
                  disabledMouseCursor: SystemMouseCursors.forbidden,
                ),
                onPressed: () async {
                  final name = nameController.text.trim();
                  final sku = skuController.text.trim();
                  final price = double.tryParse(priceController.text) ?? 0.0;
                  final stock = int.tryParse(stockController.text) ?? 0;

                  if (name.isNotEmpty && price > 0) {
                    if (existingProduct == null) {
                      await db.into(db.products).insert(
                            ProductsCompanion.insert(
                              name: name,
                              sku: sku,
                              price: price,
                              stockQuantity: Value(stock),
                              imageUrl: Value(selectedImagePath),
                              subcategoryId: Value(selectedSubcategoryId),
                            ),
                          );
                    } else {
                      await (db.update(db.products)
                            ..where((p) => p.id.equals(existingProduct.id)))
                          .write(
                        ProductsCompanion(
                          name: Value(name),
                          sku: Value(sku),
                          price: Value(price),
                          stockQuantity: Value(stock),
                          imageUrl: Value(selectedImagePath),
                          subcategoryId: Value(selectedSubcategoryId),
                        ),
                      );
                    }
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ================= CATEGORY / SUBCATEGORY MODAL =================
  void _showAddCategoryModal(
      BuildContext context, WidgetRef ref, AppDatabase db) {
    final categoryNameController = TextEditingController();
    final subcategoryNameController = TextEditingController();
    int? parentCatId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final categoriesAsync = ref.watch(categoriesProvider);

          return AlertDialog(
            title: const Text('Manage Categories & Subcategories'),
            content: SizedBox(
              width: 450,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('1. Create New Main Category',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: categoryNameController,
                            decoration: const InputDecoration(
                              labelText: 'Category Name',
                              hintText: 'e.g., Beverages, Food',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            enabledMouseCursor: SystemMouseCursors.click,
                            disabledMouseCursor: SystemMouseCursors.forbidden,
                          ),
                          onPressed: () async {
                            final name = categoryNameController.text.trim();
                            if (name.isNotEmpty) {
                              await db.into(db.categories).insert(
                                    CategoriesCompanion.insert(name: name),
                                  );
                              categoryNameController.clear();
                            }
                          },
                          child: const Text('Create'),
                        ),
                      ],
                    ),
                    const Divider(height: 30),
                    const Text('2. Create Subcategory under Category',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    categoriesAsync.when(
                      data: (categories) {
                        return Column(
                          children: [
                            DropdownButtonFormField<int>(
                              mouseCursor: SystemMouseCursors.click,
                              initialValue: parentCatId,
                              decoration: const InputDecoration(
                                labelText: 'Select Main Category',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: categories.map((cat) {
                                return DropdownMenuItem(
                                  value: cat.id,
                                  child: Text(cat.name),
                                );
                              }).toList(),
                              onChanged: (val) =>
                                  setState(() => parentCatId = val),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: subcategoryNameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Subcategory Name',
                                      hintText: 'e.g., Cold Drinks',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    enabledMouseCursor:
                                        SystemMouseCursors.click,
                                    disabledMouseCursor:
                                        SystemMouseCursors.forbidden,
                                  ),
                                  onPressed: parentCatId == null
                                      ? null
                                      : () async {
                                          final subName =
                                              subcategoryNameController.text
                                                  .trim();
                                          if (subName.isNotEmpty) {
                                            await db
                                                .into(db.subcategories)
                                                .insert(
                                                  SubcategoriesCompanion.insert(
                                                    categoryId: parentCatId!,
                                                    name: subName,
                                                  ),
                                                );
                                            subcategoryNameController.clear();
                                          }
                                        },
                                  child: const Text('Add Sub'),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Error: $e'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  enabledMouseCursor: SystemMouseCursors.click,
                  disabledMouseCursor: SystemMouseCursors.forbidden,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteProduct(
      BuildContext context, AppDatabase db, Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product.name}"?'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              enabledMouseCursor: SystemMouseCursors.click,
              disabledMouseCursor: SystemMouseCursors.forbidden,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              enabledMouseCursor: SystemMouseCursors.click,
              disabledMouseCursor: SystemMouseCursors.forbidden,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await (db.delete(db.products)
                    ..where((p) => p.id.equals(product.id)))
                  .go();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
