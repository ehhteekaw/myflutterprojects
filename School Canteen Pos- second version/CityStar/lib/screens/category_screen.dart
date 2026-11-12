import 'package:flutter/material.dart';

import '../services/api_service.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});
  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  List<dynamic> _categories = [];
  List<dynamic> _subcategories = [];

  int? _selectedCategoryId;
  String? _selectedCategoryName;

  bool _isLoadingCat = true;
  bool _isLoadingSub = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCat = true);
    final data = await ApiService().getCategories();
    setState(() {
      _categories = data;
      _isLoadingCat = false;

      if (_categories.isNotEmpty && _selectedCategoryId == null) {
        _selectCategory(_categories[0]);
      } else if (_categories.isEmpty) {
        _selectedCategoryId = null;
        _selectedCategoryName = null;
        _subcategories = [];
      }
    });
  }

  void _selectCategory(dynamic category) {
    setState(() {
      _selectedCategoryId = category['id'];
      _selectedCategoryName = category['name'];
    });
    _loadSubcategories(category['id']);
  }

  void _showAddCategoryDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Category'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Category Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              final success = await ApiService().addCategory(ctrl.text.trim());
              if (success && mounted) {
                Navigator.pop(context);
                _loadCategories();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteCategory(int id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text(
          'Are you sure you want to delete "$name"?\nAll subcategories inside it will also be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ApiService().deleteCategory(id);
              if (success && mounted) {
                if (_selectedCategoryId == id) _selectedCategoryId = null;
                _loadCategories();
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSubcategories(int categoryId) async {
    setState(() => _isLoadingSub = true);
    final data = await ApiService().getSubcategories(categoryId);
    setState(() {
      _subcategories = data;
      _isLoadingSub = false;
    });
  }

  void _showAddSubcategoryDialog() {
    if (_selectedCategoryId == null) return;
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Subcategory to $_selectedCategoryName'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Subcategory Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              final success = await ApiService().addSubcategory(
                _selectedCategoryId!,
                ctrl.text.trim(),
              );
              if (success && mounted) {
                Navigator.pop(context);
                _loadSubcategories(_selectedCategoryId!);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
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
              children: const [
                Text(
                  'Manage Categories & Subcategories',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                // SizedBox(height: 4),
                // Text(
                //   'Add, edit, or delete categories and subcategories here.',
                //   style: TextStyle(fontSize: 14, color: Colors.grey),
                // ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // ================= BOTTOM: Category & Subcategory =================
          Expanded(
            child: Row(
              children: [
                // ----- LEFT SIDE: Categories -----
                Expanded(
                  flex: 1,
                  child: Container(
                    color: Colors.grey[50],
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[700],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _showAddCategoryDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Category'),
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: _isLoadingCat
                              ? const Center(child: CircularProgressIndicator())
                              : ListView.builder(
                                  itemCount: _categories.length,
                                  itemBuilder: (context, index) {
                                    final cat = _categories[index];
                                    final isSelected =
                                        cat['id'] == _selectedCategoryId;
                                    return Material(
                                      color: Colors.transparent,
                                      child: ListTile(
                                        selected: isSelected,
                                        selectedTileColor: Colors.blue.shade50,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 4,
                                            ),
                                        title: Text(
                                          cat['name'],
                                          style: TextStyle(
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: isSelected
                                                ? Colors.blue[800]
                                                : Colors.black87,
                                          ),
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                            size: 20,
                                          ),
                                          onPressed: () => _deleteCategory(
                                            cat['id'],
                                            cat['name'],
                                          ),
                                        ),
                                        onTap: () => _selectCategory(cat),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ----- RIGHT SIDE: Subcategories -----
                Expanded(
                  flex: 2,
                  child: Container(
                    color: Colors.white,
                    child: _selectedCategoryId == null
                        ? const Center(
                            child: Text(
                              'Select a category to see subcategories.',
                            ),
                          )
                        : Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Subcategories of "$_selectedCategoryName"',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green[600],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onPressed: _showAddSubcategoryDialog,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add Subcategory'),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              Expanded(
                                child: _isLoadingSub
                                    ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    : _subcategories.isEmpty
                                    ? const Center(
                                        child: Text('No subcategories found.'),
                                      )
                                    : ListView.builder(
                                        itemCount: _subcategories.length,
                                        itemBuilder: (context, index) {
                                          final sub = _subcategories[index];
                                          return Material(
                                            child: ListTile(
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 4,
                                                  ),
                                              leading: const Icon(
                                                Icons.subdirectory_arrow_right,
                                                color: Colors.blueGrey,
                                              ),
                                              title: Text(sub['name']),
                                              trailing: IconButton(
                                                icon: const Icon(
                                                  Icons.delete,
                                                  color: Colors.red,
                                                  size: 20,
                                                ),
                                                onPressed: () async {
                                                  final confirm = await showDialog<bool>(
                                                    context: context,
                                                    builder: (_) => AlertDialog(
                                                      title: const Text(
                                                        'Delete Subcategory?',
                                                      ),
                                                      content: Text(
                                                        'Are you sure you want to delete "${sub['name']}"?',
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                context,
                                                                false,
                                                              ),
                                                          child: const Text(
                                                            'Cancel',
                                                          ),
                                                        ),
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                context,
                                                                true,
                                                              ),
                                                          child: const Text(
                                                            'Delete',
                                                            style: TextStyle(
                                                              color: Colors.red,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirm == true) {
                                                    final success =
                                                        await ApiService()
                                                            .deleteSubcategory(
                                                              sub['id'],
                                                            );
                                                    if (success && mounted) {
                                                      _loadSubcategories(
                                                        _selectedCategoryId!,
                                                      );
                                                    }
                                                  }
                                                },
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
