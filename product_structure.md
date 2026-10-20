# Anamel POS — Product Architecture

هذا المستند يشرح هيكلة نظام المنتجات في مشروع **Anamel POS**، والمسؤولية الخاصة بكل ملف، والعلاقة بين `Product` و`ProductVariant` و`ColorStock`، بالإضافة إلى بنية قاعدة البيانات وطبقات الوصول إلى البيانات.

---

## 1. هيكل الملفات

نظام المنتجات موزع داخل مجلد `lib` بالشكل التالي:

```text
lib/
│
├── models/
│   └── product_model.dart
│
└── services/
    ├── product_helper.dart
    ├── product_dao.dart
    ├── product_variant_dao.dart
    └── product_color_stock_dao.dart
```

### Models

```text
models/
└── product_model.dart
```

يحتوي على نماذج البيانات التي تمثل المنتج ومكوناته:

- `Product`
- `ProductVariant`
- `ColorStock`

### Services

```text
services/
├── product_helper.dart
├── product_dao.dart
├── product_variant_dao.dart
└── product_color_stock_dao.dart
```

تحتوي على طبقة التعامل مع قاعدة البيانات والعمليات الخاصة بالمنتجات والـ Variants والألوان والمخزون.

---

# 2. الهيكل المنطقي للمنتج

المنتج في النظام لا يمثل قطعة واحدة بمعلومات بسيطة، بل يمتلك بنية هرمية:

```text
Product
│
├── Categories
│
├── Images
│   ├── image1
│   ├── image2
│   ├── image3
│   └── image4
│
└── Variants
    │
    ├── Age
    ├── Sale Price
    ├── Purchase Price
    │
    └── Colors
        ├── Color Name
        ├── Color Value
        └── Stock
```

مثال:

```text
بدلة قطنية
│
├── التصنيفات
│   ├── مواليد
│   └── ملابس يومية
│
├── 1-2 سنة
│   ├── أبيض → 3
│   ├── وردي → 2
│   └── أزرق → 4
│
├── 2-4 سنوات
│   ├── أبيض → 5
│   ├── وردي → 3
│   └── أزرق → 2
│
└── 4-6 سنوات
    ├── أبيض → 1
    ├── وردي → 0
    └── أزرق → 3
```

**المبدأ الأساسي:**

> السعر مرتبط بالعمر/الـ Variant، بينما المخزون مرتبط باللون داخل ذلك الـ Variant.

بالتالي يمكن أن يكون للمنتج نفس اللون في عدة أعمار، مع اختلاف السعر والمخزون لكل عمر.

---

# 3. `product_model.dart`

المسار:

```text
lib/models/product_model.dart
```

هذا الملف يحتوي على نماذج البيانات الأساسية لنظام المنتجات.

يستورد `flutter/material.dart` لأن `ColorStock` يوفر Getter يحول القيمة المخزنة للون إلى كائن `Color` يمكن استخدامه مباشرة في واجهة Flutter.

---

## 3.1 `Product`

يمثل المنتج الرئيسي.

```dart
class Product {
  final int id;
  final String name;
  final List<int> categoryIDs;

  final String image1;
  final String image2;
  final String image3;
  final String image4;

  final List<ProductVariant> variants;
}
```

### خصائص Product

| الخاصية | النوع | الوظيفة |
|---|---|---|
| `id` | `int` | معرف المنتج |
| `name` | `String` | اسم المنتج |
| `categoryIDs` | `List<int>` | التصنيفات المرتبطة بالمنتج |
| `image1` | `String` | الصورة الأولى |
| `image2` | `String` | الصورة الثانية |
| `image3` | `String` | الصورة الثالثة |
| `image4` | `String` | الصورة الرابعة |
| `variants` | `List<ProductVariant>` | الأعمار/الـ Variants الخاصة بالمنتج |

---

## 3.2 `Product.totalStock`

```dart
int get totalStock
```

يحسب إجمالي مخزون المنتج بجميع الـ Variants والألوان.

العملية منطقياً:

```text
Product
    ↓
Variants
    ↓
مجموع مخزون كل Variant
    ↓
Total Stock
```

مثال:

```text
1-2 سنة = 9
2-4 سنوات = 10
4-6 سنوات = 4

Total = 23
```

---

## 3.3 `Product.salePrice`

```dart
double get salePrice
```

يعيد **أدنى سعر بيع** بين جميع الـ Variants.

إذا لم يكن هناك أي Variant:

```text
0.0
```

مثال:

```text
1-2 سنة  → 2500
2-4 سنوات → 2800
4-6 سنوات → 3000

salePrice = 2500
```

يوجد أيضًا:

```dart
double get saleprice => salePrice;
double get totalPrice => salePrice;
```

وهما مسميات بديلة للوصول إلى نفس القيمة.

---

## 3.4 `Product.size`

```dart
List<String> get size
```

يعيد قائمة الأعمار الموجودة في الـ Variants.

مثال:

```dart
[
  '1-2 سنة',
  '2-4 سنوات',
  '4-6 سنوات',
]
```

---

# 4. `ProductVariant`

يمثل نسخة من المنتج حسب العمر.

```dart
class ProductVariant {
  final int id;
  final String age;
  final double salePrice;
  final double purchasePrice;
  final List<ColorStock> colors;
}
```

### خصائصه

| الخاصية | الوظيفة |
|---|---|
| `id` | معرف الـ Variant |
| `age` | العمر |
| `salePrice` | سعر البيع |
| `purchasePrice` | سعر الشراء |
| `colors` | ألوان ومخزون هذا العمر |

### قاعدة مهمة

السعر لا يوجد داخل `ColorStock`.

أي أن:

```text
1-2 سنة
    السعر = 2500
    أبيض = 3
    وردي = 2
    أزرق = 4
```

وليس:

```text
أبيض = 2500
وردي = 2600
أزرق = 2700
```

فاللون مسؤول عن المخزون فقط، بينما الـ Variant مسؤول عن السعر.

---

## 4.1 `ProductVariant.totalStock`

```dart
int get totalStock
```

يحسب مجموع المخزون لجميع ألوان الـ Variant.

مثال:

```text
1-2 سنة

أبيض = 3
وردي = 2
أزرق = 4

Total = 9
```

---

# 5. `ColorStock`

يمثل لونًا محددًا داخل Variant معين.

```dart
class ColorStock {
  final int id;
  final String colorName;
  final int colorValue;
  final int stock;
}
```

### الخصائص

| الخاصية | النوع | الوظيفة |
|---|---|---|
| `id` | `int` | معرف سجل اللون |
| `colorName` | `String` | اسم اللون |
| `colorValue` | `int` | قيمة اللون بصيغة ARGB |
| `stock` | `int` | كمية المخزون |

مثال:

```text
colorName  = "وردي"
colorValue = 0xFFFFC0CB
stock      = 5
```

---

## 5.1 `ColorStock.color`

```dart
Color get color => Color(colorValue);
```

يحول قيمة `colorValue` المخزنة في قاعدة البيانات إلى `Color` لاستخدامها مباشرة في Flutter.

---

# 6. `product_helper.dart`

المسار:

```text
lib/services/product_helper.dart
```

هذا الملف مسؤول عن إنشاء وإدارة اتصال قاعدة بيانات المنتجات.

يحتوي على:

```dart
class AnamelDatabase
```

وقاعدة البيانات المستخدمة هي:

```text
anamel.db
```

ويتم استخدام:

```text
sqflite_common_ffi
```

لتشغيل SQLite على Desktop.

---

# 7. Database Singleton

يستخدم `AnamelDatabase` نمط Singleton:

```dart
static final AnamelDatabase instance = AnamelDatabase._();
```

وبالتالي تحصل بقية طبقات الـ DAO على نفس instance:

```dart
AnamelDatabase.instance
```

كما أن الاتصال يتم فتحه عند الحاجة وإعادة استخدامه طالما أنه مفتوح.

---

# 8. Database Version

الإصدار الحالي:

```dart
static const int _databaseVersion = 1;
```

عند إجراء تغيير مستقبلي على بنية قاعدة البيانات يجب رفع الإصدار وإنشاء migration مناسبة داخل:

```dart
_onUpgrade()
```

---

# 9. Database Schema

قاعدة البيانات تحتوي على الجداول الأساسية التالية:

```text
categories
products
product_categories
product_variants
product_variant_colors
```

---

## 9.1 `categories`

يخزن التصنيفات.

```text
categories
├── id
├── name
├── created_at
└── updated_at
```

---

## 9.2 `products`

يخزن المعلومات الأساسية للمنتج.

```text
products
├── id
├── name
├── image1
├── image2
├── image3
├── image4
├── created_at
└── updated_at
```

الصور الأربع مخزنة كقيم `TEXT`، بينما الـ Model يتعامل معها كـ `String`.

---

# 10. Product ↔ Category

العلاقة بين المنتجات والتصنيفات هي:

```text
Product ←→ Category
```

أي أن المنتج يمكن أن ينتمي إلى أكثر من تصنيف.

لذلك توجد جدول وسيط:

```text
product_categories
├── product_id
└── category_id
```

مع:

```text
PRIMARY KEY (product_id, category_id)
```

---

# 11. `product_variants`

هذا الجدول يمثل الـ Variants الخاصة بكل منتج.

```text
product_variants
├── id
├── product_id
├── age
├── sale_price
├── purchase_price
├── created_at
└── updated_at
```

العلاقة:

```text
Product
   │
   └── has many
          ↓
      ProductVariant
```

كما أن:

```text
UNIQUE(product_id, age)
```

يمنع وجود Variantين بنفس العمر للمنتج نفسه.

---

# 12. `product_variant_colors`

هذا الجدول يمثل ألوان كل Variant ومخزونها.

```text
product_variant_colors
├── id
├── variant_id
├── color_name
├── color_value
├── stock
├── created_at
└── updated_at
```

العلاقة:

```text
ProductVariant
      │
      └── has many
             ↓
         ColorStock
```

كما أن:

```text
UNIQUE(variant_id, color_name)
```

يمنع تكرار نفس اسم اللون داخل الـ Variant نفسه.

---

# 13. العلاقات الكاملة

البنية الكاملة:

```text
                         ┌──────────────┐
                         │  Categories  │
                         └──────┬───────┘
                                │
                         many-to-many
                                │
                         ┌──────▼───────┐
                         │   Product    │
                         │              │
                         │ name         │
                         │ image1..4    │
                         └──────┬───────┘
                                │
                             1 : N
                                │
                    ┌───────────▼───────────┐
                    │    ProductVariant     │
                    │                       │
                    │ age                   │
                    │ salePrice             │
                    │ purchasePrice         │
                    └───────────┬───────────┘
                                │
                             1 : N
                                │
                    ┌───────────▼───────────┐
                    │      ColorStock        │
                    │                       │
                    │ colorName              │
                    │ colorValue             │
                    │ stock                  │
                    └───────────────────────┘
```

---

# 14. `product_dao.dart`

المسار:

```text
lib/services/product_dao.dart
```

هذا هو الـ DAO الرئيسي للمنتجات.

```dart
class ProductDao
```

وهو المسؤول عن:

- إضافة المنتجات
- تعديل المنتجات
- حذف المنتجات
- جلب منتج واحد
- جلب جميع المنتجات
- البحث عن المنتجات
- جلب المنتجات حسب التصنيف
- حساب المخزون الكلي للمنتج
- حساب عدد المنتجات
- إدارة التصنيفات
- جلب المنتجات حسب أسماء التصنيفات
- إنشاء التصنيفات الافتراضية

---

# 15. إضافة Product

عند:

```dart
insert(Product product)
```

يتم إنشاء المنتج ضمن Transaction واحدة.

التدفق:

```text
ProductDao.insert()
       │
       ├── Validate Product
       │
       ├── Insert Product
       │
       ├── Replace Categories
       │
       └── For each Variant
              │
              ▼
        ProductVariantDao.insert()
              │
              └── Colors
                    │
                    ▼
             ProductColorStockDao.insert()
```

وبذلك يتم إنشاء المنتج وجميع مكوناته كوحدة واحدة.

---

# 16. تعديل Product

عند تعديل المنتج:

```dart
update(Product product)
```

يتم:

1. التحقق من صحة المنتج.
2. تحديث بيانات المنتج.
3. استبدال علاقات التصنيفات.
4. جلب الـ Variants الموجودة.
5. حذف الـ Variants التي لم تعد موجودة.
6. تحديث الـ Variants الموجودة.
7. إضافة الـ Variants الجديدة.

ويحاول النظام الحفاظ على IDs الموجودة للـ Variants قدر الإمكان.

---

# 17. حذف Product

عند:

```dart
delete(productId)
```

يتم حذف المنتج.

وبسبب استخدام:

```sql
ON DELETE CASCADE
```

تتم إزالة العلاقات التابعة أيضًا:

```text
Product
  │
  ├── product_categories
  │
  └── product_variants
          │
          └── product_variant_colors
```

وهذا يعني أن حذف المنتج لا يحتاج إلى حذف كل مستوى يدويًا.

---

# 18. البحث عن المنتجات

يوفر `ProductDao`:

```dart
search(String query)
```

ويتم البحث في اسم المنتج باستخدام:

```sql
name LIKE '%query%'
```

إذا كان البحث فارغًا، يتم إرجاع جميع المنتجات.

---

# 19. البحث حسب التصنيف

يوفر النظام:

```dart
getByCategory(int categoryId)
```

بالإضافة إلى:

```dart
getByCategoryName(String categoryName)
```

و:

```dart
getByCategories(List<String> categoryNames)
```

الدالة الأخيرة تدعم اختيار عدة تصنيفات، وتبحث عن المنتجات التي تنتمي إلى **جميع التصنيفات المحددة**.

مثال:

```text
[مواليد, ملابس يومية]
```

يعني أن المنتج يجب أن يكون مرتبطًا بالتصنيفين معًا.

أما:

```text
الكل
```

فتؤدي إلى جلب جميع المنتجات.

---

# 20. إدارة التصنيفات

`ProductDao` يحتوي أيضًا على عمليات التصنيفات:

```dart
getCategories()
insertCategory()
updateCategory()
deleteCategory()
```

وبذلك لا توجد حاجة إلى DAO منفصل للتصنيفات ضمن البنية الحالية.

---

# 21. `product_variant_dao.dart`

المسار:

```text
lib/services/product_variant_dao.dart
```

هذا الـ DAO مسؤول عن التعامل مع:

```text
ProductVariant
```

وهو المستوى الموجود بين المنتج والألوان.

يعتمد على:

```dart
ProductColorStockDao
```

لإدارة ألوان الـ Variant.

---

# 22. إضافة Variant

عند:

```dart
insert(ProductVariant variant)
```

يتم التحقق من:

```text
age
salePrice
purchasePrice
```

ثم:

```text
Insert Variant
      ↓
الحصول على variantId
      ↓
إضافة جميع الألوان
```

أي:

```text
ProductVariantDao
        │
        ├── product_variants
        │
        └── ProductColorStockDao
                ↓
        product_variant_colors
```

---

# 23. تعديل Variant

عند:

```dart
update(ProductVariant variant)
```

يتم تحديث:

```text
age
sale_price
purchase_price
```

ثم تتم مزامنة الألوان.

المزامنة تقوم بـ:

```text
الألوان القديمة
       │
       ├── غير موجودة في البيانات الجديدة
       │       ↓
       │      DELETE
       │
       ├── موجودة
       │       ↓
       │      UPDATE
       │
       └── جديدة
               ↓
              INSERT
```

وهذا يسمح بتعديل قائمة الألوان بالكامل من خلال Variant واحد.

---

# 24. جلب Variant

يوفر:

```dart
getById()
```

لجلب Variant واحد.

كما يوفر:

```dart
getByProductId()
```

لجلب جميع Variants الخاصة بمنتج.

و:

```dart
getByProductAndAge()
```

للعثور على Variant حسب المنتج والعمر.

---

# 25. مخزون Variant

يمكن الحصول على إجمالي مخزون Variant باستخدام:

```dart
getTotalStockByVariantId()
```

والقيمة هي مجموع مخزون جميع ألوان ذلك العمر.

---

# 26. `product_color_stock_dao.dart`

المسار:

```text
lib/services/product_color_stock_dao.dart
```

هذا هو المستوى المسؤول عن:

```text
ColorStock
```

أي:

- اسم اللون
- قيمة اللون
- المخزون

ولا يتعامل مع السعر.

---

# 27. عمليات ColorStock

يوفر DAO العمليات التالية:

```text
insert()
update()
setStock()
changeStock()
getById()
getByVariantId()
getByVariantAndColorName()
getTotalStockByVariantId()
delete()
deleteByVariantId()
```

---

# 28. تغيير المخزون

يوجد فرق بين:

```dart
setStock()
```

و:

```dart
changeStock()
```

### `setStock`

يحدد القيمة الجديدة مباشرة:

```text
stock = 10
```

### `changeStock`

يغير المخزون بمقدار معين:

```text
changeStock(id, 5)
```

تعني:

```text
stock += 5
```

بينما:

```text
changeStock(id, -2)
```

تعني:

```text
stock -= 2
```

ولا يسمح النظام بأن يصبح المخزون أقل من صفر.

---

# 29. حساب المخزون

يمكن حساب المخزون على ثلاثة مستويات:

### مستوى اللون

```text
ColorStock.stock
```

### مستوى Variant

```text
ProductVariant.totalStock
```

أو عبر DAO:

```dart
getTotalStockByVariantId()
```

### مستوى Product

```text
Product.totalStock
```

وبذلك:

```text
Color Stock
     ↓
Variant Stock
     ↓
Product Stock
```

---

# 30. Validation

النظام يحتوي على عمليات تحقق قبل الحفظ.

## Product

اسم المنتج يجب ألا يكون فارغًا.

## ProductVariant

العمر يجب ألا يكون فارغًا.

سعر البيع:

```text
>= 0
```

سعر الشراء:

```text
>= 0
```

## ColorStock

اسم اللون يجب ألا يكون فارغًا.

المخزون:

```text
>= 0
```

هذه القواعد موجودة على مستوى الـ DAO، بالإضافة إلى وجود `CHECK` في قاعدة البيانات للمخزون والأسعار.

---

# 31. Transactions

إضافة وتعديل المنتج يتمان داخل:

```dart
db.transaction(...)
```

وهذا مهم لأن المنتج يتكون من عدة سجلات مترابطة.

مثلاً عند إضافة:

```text
Product
 ├── Categories
 ├── Variant 1
 │    ├── Color 1
 │    └── Color 2
 └── Variant 2
      ├── Color 1
      └── Color 2
```

يتم تنفيذ العملية كوحدة واحدة.

---

# 32. Database Indexes

تم إنشاء Indexes لتحسين عمليات البحث والاستعلام:

```text
idx_products_name

idx_product_categories_product
idx_product_categories_category

idx_product_variants_product
idx_product_variants_age

idx_variant_colors_variant
idx_variant_colors_name
```

وهذا يساعد خصوصًا في عمليات البحث والربط بين الجداول.

---

# 33. Cascade Delete

العلاقات تعتمد على:

```sql
ON DELETE CASCADE
```

لذلك:

```text
Delete Product
      ↓
Product Categories
      ↓
Product Variants
      ↓
Variant Colors
```

يتم تنظيف البيانات التابعة تلقائيًا.

وبالمثل:

```text
Delete Variant
      ↓
Variant Colors
```

---

# 34. تدفق البيانات الكامل

عند قراءة Product من قاعدة البيانات:

```text
ProductDao
    │
    ├── products
    │
    ├── product_categories
    │
    └── ProductVariantDao
            │
            ├── product_variants
            │
            └── ProductColorStockDao
                    │
                    └── product_variant_colors
```

ثم يتم إعادة بناء الـ Model:

```text
Database
   ↓
Product
   ↓
ProductVariant[]
   ↓
ColorStock[]
```

---

# 35. مسؤولية كل ملف باختصار

| الملف | المسؤولية |
|---|---|
| `product_model.dart` | تعريف نماذج Product و Variant و ColorStock |
| `product_helper.dart` | إنشاء وإدارة قاعدة بيانات المنتجات والجداول والفهارس |
| `product_dao.dart` | إدارة المنتجات والتصنيفات |
| `product_variant_dao.dart` | إدارة Variants والأعمار والأسعار وربطها بالألوان |
| `product_color_stock_dao.dart` | إدارة ألوان الـ Variants والمخزون |

---

# 36. قاعدة التصميم الأساسية

نظام المنتجات مبني على فصل واضح بين:

```text
Product
    = المنتج الأساسي
```

```text
ProductVariant
    = اختلاف المنتج حسب العمر + السعر
```

```text
ColorStock
    = اللون + المخزون لهذا العمر
```

وبالتالي:

> **Color لا يحدد السعر.**

السعر موجود على مستوى:

```text
ProductVariant
```

بينما المخزون موجود على مستوى:

```text
ColorStock
```

وهذا يسمح مثلًا بأن يكون:

```text
فستان
│
├── 1-2 سنة
│   ├── أبيض → 2500 / 5
│   ├── وردي → 2500 / 3
│   └── أزرق → 2500 / 2
│
└── 2-4 سنوات
    ├── أبيض → 2800 / 4
    ├── وردي → 2800 / 6
    └── أزرق → 2800 / 1
```

حيث الرقم الأول هو السعر والرقم الثاني هو المخزون.

---

# 37. إضافة بيانات ابتدائية

`ProductDao` يحتوي على:

```dart
seedInitialDataIfEmpty()
```

وعند عدم وجود منتجات، يتم إنشاء مجموعة من التصنيفات الافتراضية، مثل:

```text
مواليد
فساتين
ملابس يومية
جاكيتات
سالوبيت
بلوزات
بناطيل
```

ويتم التأكد من عدم تكرار التصنيف قبل إضافته.

---

# 38. Development Database Reset

يوفر `AnamelDatabase`:

```dart
deleteDatabase()
```

وهي مخصصة للتطوير.

تقوم بـ:

1. إغلاق قاعدة البيانات.
2. تحديد مسار `anamel.db`.
3. حذف ملف قاعدة البيانات إذا كان موجودًا.

> لا ينبغي استخدام هذه العملية كجزء من منطق الإنتاج لأنها تؤدي إلى حذف قاعدة البيانات وإعادة إنشائها.

---

# 39. Architecture Overview

يمكن تلخيص الـ architecture بالشكل التالي:

```text
                 Flutter UI
                     │
                     ▼
              ┌─────────────┐
              │ ProductDao  │
              └──────┬──────┘
                     │
             ┌───────▼────────┐
             │ ProductVariant │
             │      Dao       │
             └───────┬────────┘
                     │
             ┌───────▼──────────────┐
             │ ProductColorStockDao │
             └───────┬──────────────┘
                     │
                     ▼
              ┌─────────────┐
              │ SQLite DB   │
              │  anamel.db  │
              └─────────────┘
```

والـ Models تمثل البيانات التي تنتقل بين الواجهة وطبقة الـ DAO:

```text
Product
   │
   └── ProductVariant[]
          │
          └── ColorStock[]
```

---

# 40. الخلاصة

نظام المنتجات في **Anamel POS** يعتمد على بنية هرمية واضحة:

```text
Product
   │
   ├── Categories
   │
   ├── Images
   │
   └── ProductVariants
          │
          ├── Age
          ├── Sale Price
          ├── Purchase Price
          │
          └── ColorStock
                 ├── Color
                 └── Stock
```

وتنقسم المسؤوليات إلى خمس طبقات/ملفات رئيسية:

```text
product_model.dart
        ↓
نماذج البيانات

product_helper.dart
        ↓
قاعدة البيانات

product_dao.dart
        ↓
Products + Categories

product_variant_dao.dart
        ↓
Variants + Ages + Prices

product_color_stock_dao.dart
        ↓
Colors + Stock
```

هذه البنية تجعل نظام المنتجات قابلًا للتوسع مع الحفاظ على فصل واضح بين بيانات المنتج، اختلافاته حسب العمر، والمخزون حسب اللون.