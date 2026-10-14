import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/product_model.dart';
import '../../services/product_dao.dart';
import '../anamel_colors.dart';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

/// خيار لون مسبق الإعداد
class _ColorPreset {
  final String name;
  final int value;

  const _ColorPreset({
    required this.name,
    required this.value,
  });
}

const List<_ColorPreset> _presetColors = [
  _ColorPreset(name: 'أبيض', value: 0xFFFFFFFF),
  _ColorPreset(name: 'أسود', value: 0xFF222222),
  _ColorPreset(name: 'وردي', value: 0xFFFFB6C1),
  _ColorPreset(name: 'وردي فاتح', value: 0xFFFCE4EC),
  _ColorPreset(name: 'أزرق', value: 0xFF2196F3),
  _ColorPreset(name: 'سماوي', value: 0xFF81D4FA),
  _ColorPreset(name: 'كحلي', value: 0xFF1A237E),
  _ColorPreset(name: 'بيج', value: 0xFFF5F5DC),
  _ColorPreset(name: 'رمادي', value: 0xFF9E9E9E),
  _ColorPreset(name: 'أخضر', value: 0xFF4CAF50),
  _ColorPreset(name: 'زيتي', value: 0xFF556B2F),
  _ColorPreset(name: 'أصفر', value: 0xFFFFEB3B),
  _ColorPreset(name: 'خردلي', value: 0xFFFFC107),
  _ColorPreset(name: 'أحمر', value: 0xFFF44336),
  _ColorPreset(name: 'عنابي', value: 0xFF800020),
  _ColorPreset(name: 'بنفسجي', value: 0xFF9C27B0),
  _ColorPreset(name: 'برتقالي', value: 0xFFFF9800),
  _ColorPreset(name: 'بني', value: 0xFF795548),
];

const List<String> _suggestedAges = [
  '0-3 أشهر',
  '3-6 أشهر',
  '6-12 شهر',
  '1-2 سنة',
  '2-3 سنوات',
  '3-4 سنوات',
  '4-5 سنوات',
  '5-6 سنوات',
  '6-8 سنوات',
  '8-10 سنوات',
];

/// كائن إدارة حالة اللون أثناء الإدخال
class _ColorItemModel {
  final int originalId;
  final TextEditingController nameController;
  final TextEditingController stockController;
  int colorValue;

  _ColorItemModel({
    this.originalId = 0,
    String name = 'أبيض',
    this.colorValue = 0xFFFFFFFF,
    String stock = '1',
  })  : nameController = TextEditingController(text: name),
        stockController = TextEditingController(text: stock);

  void dispose() {
    nameController.dispose();
    stockController.dispose();
  }
}

/// كائن إدارة حالة المقاس / العمر أثناء الإدخال
class _VariantItemModel {
  final int originalId;
  final TextEditingController ageController;
  final TextEditingController purchasePriceController;
  final TextEditingController salePriceController;
  final List<_ColorItemModel> colors;
  bool isExpanded;

  _VariantItemModel({
    this.originalId = 0,
    String age = '',
    String purchasePrice = '',
    String salePrice = '',
    List<_ColorItemModel>? colors,
    this.isExpanded = true,
  })  : ageController = TextEditingController(text: age),
        purchasePriceController = TextEditingController(text: purchasePrice),
        salePriceController = TextEditingController(text: salePrice),
        colors = colors ??
            [
              _ColorItemModel(name: 'أبيض', colorValue: 0xFFFFFFFF, stock: '1'),
            ];

  void dispose() {
    ageController.dispose();
    purchasePriceController.dispose();
    salePriceController.dispose();
    for (final color in colors) {
      color.dispose();
    }
  }

  int get totalStock {
    return colors.fold(
      0,
      (sum, item) =>
          sum + (int.tryParse(item.stockController.text.trim()) ?? 0),
    );
  }
}

class AddProductDialog extends StatefulWidget {
  /// إذا تم تمرير منتج، يعمل الديالوج في وضع التعديل
  final Product? initialProduct;

  const AddProductDialog({super.key, this.initialProduct});

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  final _productDao = ProductDao();

  final _nameController = TextEditingController();
  final List<String> _imagePaths = [];

  final List<_VariantItemModel> _variants = [];
  final Set<int> _selectedCategoryIds = {};
  List<Map<String, dynamic>> _availableCategories = [];

  bool _isLoadingCategories = true;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditMode => widget.initialProduct != null;

  @override
  void initState() {
    super.initState();
    _loadCategories();

    if (_isEditMode) {
      final p = widget.initialProduct!;

      _nameController.text = p.name;

      _imagePaths.clear();

      for (final image in [
        p.image1,
        p.image2,
        p.image3,
        p.image4,
      ]) {
        if (image.trim().isNotEmpty) {
          _imagePaths.add(image);
        }
      }

      _selectedCategoryIds.addAll(p.categoryIDs);
      for (final v in p.variants) {
        _variants.add(
          _VariantItemModel(
            originalId: v.id,
            age: v.age,
            purchasePrice: v.purchasePrice.toStringAsFixed(0),
            salePrice: v.salePrice.toStringAsFixed(0),
            colors: v.colors
                .map(
                  (c) => _ColorItemModel(
                    originalId: c.id,
                    name: c.colorName,
                    colorValue: c.colorValue,
                    stock: c.stock.toString(),
                  ),
                )
                .toList(),
            isExpanded: false,
          ),
        );
      }
    } else {
      // وضع الإضافة: مقاس افتراضي
      _addVariant(defaultAge: '1-2 سنة');
    }
  }

  Widget _buildEmptyImagePicker() {
    return InkWell(
      onTap: _pickProductImage,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 105,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AnamelColors.ivory.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AnamelColors.border,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AnamelColors.sage.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.add_photo_alternate_outlined,
                color: AnamelColors.sageDark,
                size: 21,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'إضافة صور المنتج',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AnamelColors.brown,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'يمكنك إضافة حتى 4 صور',
              style: TextStyle(
                fontSize: 10,
                color: AnamelColors.brown,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddImageButton() {
    return InkWell(
      onTap: _pickProductImage,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: AnamelColors.ivory,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AnamelColors.border,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              color: AnamelColors.sageDark,
              size: 22,
            ),
            SizedBox(height: 4),
            Text(
              'إضافة',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AnamelColors.brown,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(int index, String path) {
    final file = File(path);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: AnamelColors.ivory,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: index == 0 ? AnamelColors.sageDark : AnamelColors.border,
              width: index == 0 ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: file.existsSync()
              ? Image.file(
                  file,
                  fit: BoxFit.cover,
                )
              : Container(
                  color: AnamelColors.ivory,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: AnamelColors.brown,
                    size: 24,
                  ),
                ),
        ),

        // رقم الصورة
        Positioned(
          bottom: 4,
          right: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),

        // زر الحذف
        Positioned(
          top: -6,
          left: -6,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 2,
            child: InkWell(
              onTap: () => _removeProductImage(index),
              customBorder: const CircleBorder(),
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: Colors.red,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickProductImage() async {
    if (_imagePaths.length >= 4) {
      return;
    }

    final file = await FilePicker.pickFile(
      type: FileType.image,
    );

    if (file == null || file.path == null) {
      return;
    }

    final path = file.path!;

    // منع إضافة نفس الصورة مرتين
    if (_imagePaths.contains(path)) {
      return;
    }

    setState(() {
      _imagePaths.add(path);
    });
  }

  void _removeProductImage(int index) {
    setState(() {
      _imagePaths.removeAt(index);
    });
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _productDao.getCategories();
      if (mounted) {
        setState(() {
          _availableCategories = cats;
          _isLoadingCategories = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingCategories = false);
      }
    }
  }

  void _addVariant({
    String defaultAge = '',
    String purchasePrice = '',
    String salePrice = '',
    List<_ColorItemModel>? colors,
  }) {
    setState(() {
      _variants.add(
        _VariantItemModel(
          age: defaultAge,
          purchasePrice: purchasePrice,
          salePrice: salePrice,
          colors: colors,
          isExpanded: true,
        ),
      );
      _errorMessage = null;
    });
  }

  void _duplicateVariant(int index) {
    final original = _variants[index];
    final duplicatedColors = original.colors
        .map(
          (c) => _ColorItemModel(
            name: c.nameController.text,
            colorValue: c.colorValue,
            stock: c.stockController.text,
          ),
        )
        .toList();

    setState(() {
      _variants.insert(
        index + 1,
        _VariantItemModel(
          age: original.ageController.text.isNotEmpty
              ? '${original.ageController.text} (نسخة)'
              : '',
          purchasePrice: original.purchasePriceController.text,
          salePrice: original.salePriceController.text,
          colors: duplicatedColors,
          isExpanded: true,
        ),
      );
      _errorMessage = null;
    });
  }

  void _removeVariant(int index) {
    if (_variants.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب أن يحتوي المنتج على مقاس/عمر واحد على الأقل.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      final removed = _variants.removeAt(index);
      removed.dispose();
      _errorMessage = null;
    });
  }

  void _addColorToVariant(int variantIndex) {
    setState(() {
      _variants[variantIndex].colors.add(
            _ColorItemModel(
              name: 'وردي',
              colorValue: 0xFFFFB6C1,
              stock: '1',
            ),
          );
    });
  }

  void _removeColorFromVariant(int variantIndex, int colorIndex) {
    if (_variants[variantIndex].colors.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب توفر لون واحد على الأقل لهذا المقاس.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      final removed = _variants[variantIndex].colors.removeAt(colorIndex);
      removed.dispose();
    });
  }

  int get _totalProductStock {
    return _variants.fold(0, (sum, v) => sum + v.totalStock);
  }

  Future<void> _submitProduct() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال اسم المنتج.');
      return;
    }

    if (_variants.isEmpty) {
      setState(
          () => _errorMessage = 'يجب إضافة مقاس/عمر واحد على الأقل للمنتج.');
      return;
    }

    // التحقق من المقاسات والأعمار
    final seenAges = <String>{};
    for (int i = 0; i < _variants.length; i++) {
      final v = _variants[i];
      final age = v.ageController.text.trim();
      if (age.isEmpty) {
        setState(() => _errorMessage =
            'يرجى تحديد العمر أو المقاس في الحقل رقم ${i + 1}.');
        return;
      }

      if (seenAges.contains(age.toLowerCase())) {
        setState(() => _errorMessage =
            'المقاس/العمر "$age" مكرر. كل مقاس يجب أن يكون فريداً.');
        return;
      }
      seenAges.add(age.toLowerCase());

      final purchasePrice =
          double.tryParse(v.purchasePriceController.text.trim());
      if (purchasePrice == null || purchasePrice < 0) {
        setState(
            () => _errorMessage = 'يرجى إدخال سعر شراء صحيح للمقاس "$age".');
        return;
      }

      final salePrice = double.tryParse(v.salePriceController.text.trim());
      if (salePrice == null || salePrice < 0) {
        setState(
            () => _errorMessage = 'يرجى إدخال سعر بيع صحيح للمقاس "$age".');
        return;
      }

      if (v.colors.isEmpty) {
        setState(() =>
            _errorMessage = 'يجب إضافة لون واحد على الأقل للمقاس "$age".');
        return;
      }

      // التحقق من الألوان لكل مقاس
      final seenColors = <String>{};
      for (int j = 0; j < v.colors.length; j++) {
        final c = v.colors[j];
        final colorName = c.nameController.text.trim();
        if (colorName.isEmpty) {
          setState(() => _errorMessage = 'يرجى كتابة اسم اللون للمقاس "$age".');
          return;
        }

        if (seenColors.contains(colorName.toLowerCase())) {
          setState(() =>
              _errorMessage = 'اللون "$colorName" مكرر داخل المقاس "$age".');
          return;
        }
        seenColors.add(colorName.toLowerCase());

        final stock = int.tryParse(c.stockController.text.trim());
        if (stock == null || stock < 0) {
          setState(() => _errorMessage =
              'يرجى إدخال كمية صحيحة للون "$colorName" في مقاس "$age".');
          return;
        }
      }
    }

    setState(() {
      _errorMessage = null;
      _isSaving = true;
    });

    try {
      final productVariants = <ProductVariant>[];

      for (final v in _variants) {
        final colors = <ColorStock>[];
        for (final c in v.colors) {
          colors.add(
            ColorStock(
              id: c.originalId,
              colorName: c.nameController.text.trim(),
              colorValue: c.colorValue,
              stock: int.tryParse(c.stockController.text.trim()) ?? 0,
            ),
          );
        }

        productVariants.add(
          ProductVariant(
            id: v.originalId,
            age: v.ageController.text.trim(),
            salePrice:
                double.tryParse(v.salePriceController.text.trim()) ?? 0.0,
            purchasePrice:
                double.tryParse(v.purchasePriceController.text.trim()) ?? 0.0,
            colors: colors,
          ),
        );
      }

      final product = Product(
        id: _isEditMode ? widget.initialProduct!.id : 0,
        name: name,
        categoryIDs: _selectedCategoryIds.toList(),
        image1: _imagePaths.isNotEmpty ? _imagePaths[0] : '',
        image2: _imagePaths.length > 1 ? _imagePaths[1] : '',
        image3: _imagePaths.length > 2 ? _imagePaths[2] : '',
        image4: _imagePaths.length > 3 ? _imagePaths[3] : '',
        variants: productVariants,
      );

      if (_isEditMode) {
        await _productDao.update(product);
      } else {
        await _productDao.insert(product);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'حدث خطأ أثناء حفظ المنتج: $e';
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final variant in _variants) {
      variant.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.82).clamp(620.0, 850.0);
    final dialogHeight = (screenSize.height * 0.88).clamp(520.0, 780.0);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          width: dialogWidth,
          height: dialogHeight,
          decoration: BoxDecoration(
            color: AnamelColors.white,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: AnamelColors.border,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(25, 22, 25, 18),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AnamelColors.sage.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        _isEditMode
                            ? Icons.edit_rounded
                            : Icons.add_business_rounded,
                        color: AnamelColors.sageDark,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditMode
                                ? 'تعديل المنتج وتفاصيل المقاسات (Variants)'
                                : 'إضافة منتج وتفاصيل المقاسات (Variants)',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AnamelColors.brown,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _isEditMode
                                ? 'عدّل بيانات المنتج، أو أضف مقاسات وألواناً أو احذفها.'
                                : 'حدد بيانات المنتج، وأضف لكل عمر سعره الخاص وألوانه ومخزونه المتوفر.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AnamelColors.brown,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AnamelColors.brown,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AnamelColors.border),

              // Error banner if any
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  color: Colors.red.shade50,
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Colors.red, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red.shade900,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.close,
                            size: 18, color: Colors.red),
                        onPressed: () => setState(() => _errorMessage = null),
                      ),
                    ],
                  ),
                ),

              // Scrollable Form Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBasicInfoSection(),
                      const SizedBox(height: 25),
                      _buildCategoriesSection(),
                      const SizedBox(height: 25),
                      _buildVariantsSection(),
                    ],
                  ),
                ),
              ),

              const Divider(height: 1, color: AnamelColors.border),

              // Bottom Actions Bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 25, vertical: 16),
                child: Row(
                  children: [
                    // Summary chips
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AnamelColors.ivory,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AnamelColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.straighten_rounded,
                            size: 16,
                            color: AnamelColors.sageDark,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'المقاسات: ${_variants.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AnamelColors.brown,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 16,
                            color: AnamelColors.sageDark,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'إجمالي المخزون: $_totalProductStock قطعة',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AnamelColors.brown,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    _DialogButton(
                      label: 'إلغاء',
                      onPressed: () => Navigator.pop(context),
                      filled: false,
                    ),
                    const SizedBox(width: 12),
                    _DialogButton(
                      label: _isSaving
                          ? 'جاري الحفظ...'
                          : (_isEditMode ? 'حفظ التعديلات' : 'حفظ المنتج'),
                      icon: _isSaving ? null : Icons.check_circle_rounded,
                      onPressed: _isSaving ? () {} : _submitProduct,
                      filled: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SECTION 1: BASIC INFO
  // ===========================================================================

  Widget _buildBasicInfoSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AnamelColors.ivory.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AnamelColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            icon: Icons.info_outline_rounded,
            title: 'البيانات الأساسية للمنتج',
            badge: 'أساسي',
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('اسم المنتج *'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: _nameController,
                      hint: 'مثال: بدلة قطنية مطرزة، فستان وردي صيفي...',
                      icon: Icons.shopping_bag_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildFieldLabel('صور المنتج'),
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AnamelColors.sage.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'حتى 4 صور',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AnamelColors.sageDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AnamelColors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AnamelColors.border,
                        ),
                      ),
                      child: Column(
                        children: [
                          if (_imagePaths.isEmpty)
                            _buildEmptyImagePicker()
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ..._imagePaths.asMap().entries.map(
                                  (entry) {
                                    return _buildProductImage(
                                      entry.key,
                                      entry.value,
                                    );
                                  },
                                ),
                                if (_imagePaths.length < 4)
                                  _buildAddImageButton(),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 2: CATEGORIES
  // ===========================================================================

  Widget _buildCategoriesSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AnamelColors.ivory.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AnamelColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            icon: Icons.category_outlined,
            title: 'تصنيفات المنتج',
            badge: 'اختياري',
          ),
          const SizedBox(height: 12),
          if (_isLoadingCategories)
            const SizedBox(
              height: 35,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AnamelColors.sageDark,
                  ),
                ),
              ),
            )
          else if (_availableCategories.isEmpty)
            const Text(
              'لا توجد تصنيفات مضافة حالياً. يمكنك إضافة تصنيفات من الشاشة الرئيسية للمنتجات.',
              style: TextStyle(fontSize: 12, color: AnamelColors.brown),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableCategories.map((cat) {
                final id = cat['id'] as int;
                final name = cat['name'] as String;
                final isSelected = _selectedCategoryIds.contains(id);

                return FilterChip(
                  label: Text(name),
                  selected: isSelected,
                  selectedColor: AnamelColors.sage.withValues(alpha: 0.3),
                  checkmarkColor: AnamelColors.sageDark,
                  backgroundColor: AnamelColors.white,
                  side: BorderSide(
                    color: isSelected
                        ? AnamelColors.sageDark
                        : AnamelColors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                  labelStyle: TextStyle(
                    color:
                        isSelected ? AnamelColors.sageDark : AnamelColors.brown,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedCategoryIds.add(id);
                      } else {
                        _selectedCategoryIds.remove(id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 3: VARIANTS (الأعمار والمقاسات والألوان)
  // ===========================================================================

  Widget _buildVariantsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AnamelColors.sage.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.alt_route_rounded,
                color: AnamelColors.sageDark,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المقاسات والأعمار (Product Variants)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AnamelColors.brown,
                  ),
                ),
                Text(
                  'وفقاً للنظام، يمثل كل Variant عمراً معيناً بسعره الخاص، ويحتوي على ألوانه ومخزونه.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AnamelColors.brown,
                  ),
                ),
              ],
            ),
            const Spacer(),
            _DialogButton(
              label: 'إضافة مقاس جديد',
              icon: Icons.add_rounded,
              onPressed: () => _addVariant(),
              filled: true,
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Quick add common age chips
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AnamelColors.ivory.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AnamelColors.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: AnamelColors.sageDark,
              ),
              const SizedBox(width: 8),
              const Text(
                'إضافة سريعة لمقاس شائع:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AnamelColors.brown,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _suggestedAges.map((age) {
                      final isAlreadyAdded = _variants.any(
                        (v) =>
                            v.ageController.text.trim().toLowerCase() ==
                            age.toLowerCase(),
                      );

                      return Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: ActionChip(
                          avatar: Icon(
                            isAlreadyAdded ? Icons.check : Icons.add,
                            size: 13,
                            color: isAlreadyAdded
                                ? AnamelColors.sageDark
                                : AnamelColors.brown,
                          ),
                          label: Text(age),
                          backgroundColor: isAlreadyAdded
                              ? AnamelColors.sage.withValues(alpha: 0.2)
                              : AnamelColors.white,
                          side: BorderSide(
                            color: isAlreadyAdded
                                ? AnamelColors.sageDark
                                : AnamelColors.border,
                          ),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: isAlreadyAdded
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isAlreadyAdded
                                ? AnamelColors.sageDark
                                : AnamelColors.brown,
                          ),
                          onPressed: () {
                            if (isAlreadyAdded) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'المقاس "$age" مضاف بالفعل في القائمة أدناه.'),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                              return;
                            }

                            // إذا كان هناك مقاس فارغ، عبئه به، وإلا أضف جديداً
                            final emptyVariantIndex = _variants.indexWhere(
                              (v) => v.ageController.text.trim().isEmpty,
                            );

                            if (emptyVariantIndex != -1) {
                              setState(() {
                                _variants[emptyVariantIndex]
                                    .ageController
                                    .text = age;
                              });
                            } else {
                              // إذا كان هناك مقاس سابق، انسخ أسعاره للتسهيل
                              final lastVariant =
                                  _variants.isNotEmpty ? _variants.last : null;
                              _addVariant(
                                defaultAge: age,
                                purchasePrice:
                                    lastVariant?.purchasePriceController.text ??
                                        '',
                                salePrice:
                                    lastVariant?.salePriceController.text ?? '',
                              );
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // List of Variant Cards
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _variants.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, vIndex) {
            return _buildVariantCard(vIndex);
          },
        ),
      ],
    );
  }

  // ===========================================================================
  // VARIANT CARD COMPONENT
  // ===========================================================================

  Widget _buildVariantCard(int vIndex) {
    final variant = _variants[vIndex];
    final ageText = variant.ageController.text.trim();
    final displayName =
        ageText.isNotEmpty ? ageText : 'مقاس جديد #${vIndex + 1}';

    return Container(
      decoration: BoxDecoration(
        color: AnamelColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              variant.isExpanded ? AnamelColors.sageDark : AnamelColors.border,
          width: variant.isExpanded ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          InkWell(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(17),
              bottom:
                  variant.isExpanded ? Radius.zero : const Radius.circular(17),
            ),
            onTap: () {
              setState(() => variant.isExpanded = !variant.isExpanded);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      color: AnamelColors.sage.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AnamelColors.sageDark,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Price and stock summary
                  Text(
                    'البيع: ${variant.salePriceController.text.isNotEmpty ? variant.salePriceController.text : "—"} دج '
                    '• المخزون: ${variant.totalStock} قطعة (${variant.colors.length} ألوان)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AnamelColors.brown,
                    ),
                  ),
                  const Spacer(),
                  // Duplicate button
                  Tooltip(
                    message: 'نسخ هذا المقاس وألوانه',
                    child: IconButton(
                      icon: const Icon(Icons.copy_rounded,
                          size: 18, color: AnamelColors.sageDark),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _duplicateVariant(vIndex),
                    ),
                  ),
                  // Delete button
                  Tooltip(
                    message: 'حذف هذا المقاس',
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 20, color: Colors.red),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _removeVariant(vIndex),
                    ),
                  ),
                  // Expand/collapse icon
                  Icon(
                    variant.isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AnamelColors.brown,
                  ),
                ],
              ),
            ),
          ),

          if (variant.isExpanded) ...[
            const Divider(height: 1, color: AnamelColors.border),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Age, Purchase Price, Sale Price
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('العمر / المقاس *'),
                            const SizedBox(height: 6),
                            _buildTextField(
                              controller: variant.ageController,
                              hint: 'مثال: 1-2 سنة أو 12 شهر',
                              icon: Icons.child_care_rounded,
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('سعر الشراء (دج) *'),
                            const SizedBox(height: 6),
                            _buildTextField(
                              controller: variant.purchasePriceController,
                              hint: 'مثال: 1500',
                              icon: Icons.arrow_downward_rounded,
                              isNumber: true,
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('سعر البيع (دج) *'),
                            const SizedBox(height: 6),
                            _buildTextField(
                              controller: variant.salePriceController,
                              hint: 'مثال: 2200',
                              icon: Icons.sell_outlined,
                              isNumber: true,
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Colors sub-section
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AnamelColors.ivory.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AnamelColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.palette_outlined,
                              size: 17,
                              color: AnamelColors.sageDark,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              'الألوان والكميات المتوفرة لمقاس ($displayName)',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AnamelColors.brown,
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: AnamelColors.sageDark,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => _addColorToVariant(vIndex),
                              icon: const Icon(Icons.add_circle_outline_rounded,
                                  size: 16),
                              label: const Text(
                                'إضافة لون',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Colors items
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: variant.colors.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, cIndex) {
                            return _buildColorRow(vIndex, cIndex);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // COLOR ROW & PICKER COMPONENT
  // ===========================================================================

  Widget _buildColorRow(int vIndex, int cIndex) {
    final colorItem = _variants[vIndex].colors[cIndex];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AnamelColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AnamelColors.border),
      ),
      child: Row(
        children: [
          // Color indicator & picker trigger
          InkWell(
            onTap: () => _showColorPickerModal(vIndex, cIndex),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Color(colorItem.colorValue),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AnamelColors.border,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.colorize_rounded,
                size: 15,
                color: Colors.black45,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Color name
          Expanded(
            flex: 3,
            child: TextField(
              controller: colorItem.nameController,
              decoration: InputDecoration(
                hintText: 'اسم اللون (مثال: أبيض، وردي...)',
                hintStyle:
                    const TextStyle(fontSize: 12, color: AnamelColors.brown),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
                filled: true,
                fillColor: AnamelColors.ivory,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AnamelColors.border),
                ),
              ),
              style: const TextStyle(fontSize: 13, color: AnamelColors.brown),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 12),

          // Stock counter / input
          Expanded(
            flex: 2,
            child: Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.remove_circle_outline,
                      size: 20, color: AnamelColors.sageDark),
                  onPressed: () {
                    final curr =
                        int.tryParse(colorItem.stockController.text.trim()) ??
                            0;
                    if (curr > 0) {
                      setState(() {
                        colorItem.stockController.text = (curr - 1).toString();
                      });
                    }
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: colorItem.stockController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: 'الكمية',
                      hintStyle: const TextStyle(
                          fontSize: 12, color: AnamelColors.brown),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 10),
                      isDense: true,
                      filled: true,
                      fillColor: AnamelColors.ivory,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AnamelColors.border),
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AnamelColors.brown,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add_circle_outline,
                      size: 20, color: AnamelColors.sageDark),
                  onPressed: () {
                    final curr =
                        int.tryParse(colorItem.stockController.text.trim()) ??
                            0;
                    setState(() {
                      colorItem.stockController.text = (curr + 1).toString();
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Remove color button
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.red),
            visualDensity: VisualDensity.compact,
            tooltip: 'حذف هذا اللون',
            onPressed: () => _removeColorFromVariant(vIndex, cIndex),
          ),
        ],
      ),
    );
  }

  void _showColorPickerModal(int vIndex, int cIndex) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AnamelColors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'اختر لوناً',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: AnamelColors.brown,
              ),
            ),
            content: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _presetColors.map((preset) {
                    final isCurrent =
                        _variants[vIndex].colors[cIndex].colorValue ==
                            preset.value;

                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          _variants[vIndex].colors[cIndex].colorValue =
                              preset.value;
                          _variants[vIndex].colors[cIndex].nameController.text =
                              preset.name;
                        });
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: AnamelColors.ivory,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrent
                                ? AnamelColors.sageDark
                                : AnamelColors.border,
                            width: isCurrent ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Color(preset.value),
                                shape: BoxShape.circle,
                                border: Border.all(color: AnamelColors.border),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              preset.name,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AnamelColors.brown,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'إغلاق',
                  style: TextStyle(
                      color: AnamelColors.brown, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // UI HELPERS
  // ===========================================================================

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required String badge,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AnamelColors.sageDark),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AnamelColors.brown,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AnamelColors.sage.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            badge,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AnamelColors.sageDark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: AnamelColors.brown,
        fontSize: 13,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isNumber = false,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: isNumber
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
          : null,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: AnamelColors.brown,
          fontSize: 12,
        ),
        prefixIcon: Icon(
          icon,
          color: AnamelColors.sageDark,
          size: 20,
        ),
        filled: true,
        fillColor: AnamelColors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: AnamelColors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: AnamelColors.sageDark,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final bool filled;

  const _DialogButton({
    required this.label,
    this.icon,
    required this.onPressed,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    final background = filled ? AnamelColors.sageDark : AnamelColors.ivory;
    final foreground = filled ? AnamelColors.white : AnamelColors.brown;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 17,
                  color: foreground,
                ),
                const SizedBox(width: 7),
              ],
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
