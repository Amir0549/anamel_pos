import 'package:anamel_pos/services/product_dao.dart';
import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:flutter/material.dart';

class ManageCategoriesDialog extends StatefulWidget {
  const ManageCategoriesDialog({super.key});

  @override
  State<ManageCategoriesDialog> createState() => _ManageCategoriesDialogState();
}

class _ManageCategoriesDialogState extends State<ManageCategoriesDialog> {
  final ProductDao _productDao = ProductDao();
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  bool _hasChanges = false;

  final TextEditingController _newCategoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _newCategoryController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    final cats = await _productDao.getCategories();
    if (mounted) {
      setState(() {
        _categories = cats;
        _isLoading = false;
      });
    }
  }

  Future<void> _addCategory() async {
    final name = _newCategoryController.text.trim();
    if (name.isEmpty) return;

    await _productDao.insertCategory(name);
    _newCategoryController.clear();
    _hasChanges = true;
    await _loadCategories();
  }

  Future<void> _editCategory(Map<String, dynamic> category) async {
    final editController = TextEditingController(text: category['name'] as String);
    final categoryId = category['id'] as int;

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AnamelColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AnamelColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AnamelColors.sage.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: AnamelColors.sageDark,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'تعديل التصنيف',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AnamelColors.brown,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: editController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'اسم التصنيف',
                  hintStyle: const TextStyle(
                    color: AnamelColors.brown,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: AnamelColors.ivory,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: AnamelColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(
                      color: AnamelColors.sageDark,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text(
                      'إلغاء',
                      style: TextStyle(color: AnamelColors.brown),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AnamelColors.sageDark,
                      foregroundColor: AnamelColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () {
                      if (editController.text.trim().isNotEmpty) {
                        Navigator.pop(ctx, true);
                      }
                    },
                    child: const Text('حفظ التعديل'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (updated == true) {
      final newName = editController.text.trim();
      if (newName.isNotEmpty && newName != category['name']) {
        await _productDao.updateCategory(categoryId, newName);
        _hasChanges = true;
        await _loadCategories();
      }
    }
    editController.dispose();
  }

  Future<void> _deleteCategory(Map<String, dynamic> category) async {
    final categoryId = category['id'] as int;
    final categoryName = category['name'] as String;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AnamelColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AnamelColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'تأكيد الحذف',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AnamelColors.brown,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'هل أنت متأكد من حذف التصنيف "$categoryName"؟',
                style: const TextStyle(
                  fontSize: 14,
                  color: AnamelColors.brown,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text(
                      'إلغاء',
                      style: TextStyle(color: AnamelColors.brown),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: AnamelColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('حذف'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      await _productDao.deleteCategory(categoryId);
      _hasChanges = true;
      await _loadCategories();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 520,
        height: 560,
        decoration: BoxDecoration(
          color: AnamelColors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: AnamelColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AnamelColors.sage.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.category_rounded,
                          color: AnamelColors.sageDark,
                          size: 25,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إدارة التصنيفات',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AnamelColors.brown,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'عرض وتعديل وحذف التصنيفات المسجلة.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AnamelColors.brown,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context, _hasChanges),
                    icon: const Icon(Icons.close_rounded, color: AnamelColors.brown),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // حقل إضافة تصنيف جديد سريع
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newCategoryController,
                      onSubmitted: (_) => _addCategory(),
                      decoration: InputDecoration(
                        hintText: 'إضافة تصنيف جديد...',
                        hintStyle: const TextStyle(
                          color: AnamelColors.brown,
                          fontSize: 13,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        prefixIcon: const Icon(
                          Icons.add_circle_outline_rounded,
                          color: AnamelColors.sageDark,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: AnamelColors.ivory,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: const BorderSide(color: AnamelColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: const BorderSide(
                            color: AnamelColors.sageDark,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: AnamelColors.sageDark,
                    borderRadius: BorderRadius.circular(13),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(13),
                      onTap: _addCategory,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.add_rounded, color: AnamelColors.white, size: 20),
                            SizedBox(width: 6),
                            Text(
                              'إضافة',
                              style: TextStyle(
                                color: AnamelColors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(height: 1, color: AnamelColors.border),
              const SizedBox(height: 12),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AnamelColors.sageDark,
                          strokeWidth: 2.5,
                        ),
                      )
                    : _categories.isEmpty
                        ? const Center(
                            child: Text(
                              'لا توجد تصنيفات حالياً',
                              style: TextStyle(
                                color: AnamelColors.brown,
                                fontSize: 14,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _categories.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final cat = _categories[index];
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: AnamelColors.ivory,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AnamelColors.border),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.label_outline_rounded,
                                      size: 20,
                                      color: AnamelColors.sageDark,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        cat['name'] as String,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: AnamelColors.brown,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'تعديل',
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 20,
                                        color: AnamelColors.sageDark,
                                      ),
                                      onPressed: () => _editCategory(cat),
                                    ),
                                    IconButton(
                                      tooltip: 'حذف',
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 20,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () => _deleteCategory(cat),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Material(
                    color: AnamelColors.ivory,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => Navigator.pop(context, _hasChanges),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                        child: Text(
                          'إغلاق',
                          style: TextStyle(
                            color: AnamelColors.brown,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
