import 'package:anamel_pos/models/customer_model.dart';
import 'package:anamel_pos/services/barcode_print_service.dart';
import 'package:anamel_pos/widgets/anamel_colors.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';

class CustomersTable extends StatelessWidget {
  final List<Customer> customers;
  final String Function(DateTime?) formatDate;
  final ValueChanged<Customer> onOpenBarcode, onEdit, onDelete;
  const CustomersTable(
      {super.key,
      required this.customers,
      required this.formatDate,
      required this.onOpenBarcode,
      required this.onEdit,
      required this.onDelete});
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          color: AnamelColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AnamelColors.border)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: const BoxDecoration(
                color: AnamelColors.ivory,
                border: Border(bottom: BorderSide(color: AnamelColors.border))),
            child: const Row(children: [
              SizedBox(width: 50, child: Text('#', style: _h)),
              Expanded(flex: 3, child: Text('العميل', style: _h)),
              Expanded(flex: 3, child: Text('الباركود', style: _h)),
              Expanded(flex: 2, child: Text('نقاط الولاء', style: _h)),
              Expanded(flex: 2, child: Text('إجمالي المشتريات', style: _h)),
              Expanded(flex: 2, child: Text('آخر زيارة', style: _h)),
              SizedBox(
                  width: 170,
                  child: Center(child: Text('الإجراءات', style: _h)))
            ])),
        Expanded(
            child: ListView.separated(
                itemCount: customers.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AnamelColors.border),
                itemBuilder: (context, index) => _CustomerRow(
                    customer: customers[index],
                    rowNumber: index + 1,
                    formatDate: formatDate,
                    onOpenBarcode: onOpenBarcode,
                    onEdit: onEdit,
                    onDelete: onDelete)))
      ]));
}

const _h = TextStyle(
    fontWeight: FontWeight.w800, color: AnamelColors.brown, fontSize: 13);

class _CustomerRow extends StatelessWidget {
  final Customer customer;
  final int rowNumber;
  final String Function(DateTime?) formatDate;
  final ValueChanged<Customer> onOpenBarcode, onEdit, onDelete;
  const _CustomerRow(
      {required this.customer,
      required this.rowNumber,
      required this.formatDate,
      required this.onOpenBarcode,
      required this.onEdit,
      required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final barcode = customer.barcode ?? 'بدون باركود';
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(children: [
          SizedBox(
              width: 50,
              child: Text('$rowNumber',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AnamelColors.brown.withValues(alpha: .6),
                      fontSize: 13))),
          Expanded(
              flex: 3,
              child: Row(children: [
                CircleAvatar(
                    radius: 17,
                    backgroundColor: AnamelColors.sand.withValues(alpha: .4),
                    child: const Icon(Icons.person_rounded,
                        color: AnamelColors.brown, size: 19)),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      Text(customer.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AnamelColors.brown)),
                      if (customer.phone != null &&
                          customer.phone!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(customer.phone!,
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                                fontSize: 11.5,
                                color: AnamelColors.brown.withValues(alpha: .6),
                                fontWeight: FontWeight.w500))
                      ]
                    ]))
              ])),
          Expanded(
              flex: 3,
              child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onOpenBarcode(customer),
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: AnamelColors.ivory,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AnamelColors.border)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (customer.barcode != null &&
                            customer.barcode!.isNotEmpty)
                          SizedBox(
                              width: 48,
                              height: 20,
                              child: BarcodeWidget(
                                  barcode: Barcode.code128(),
                                  data: customer.barcode!,
                                  drawText: false,
                                  color: AnamelColors.brown))
                        else
                          const Icon(Icons.qr_code_rounded,
                              size: 16, color: AnamelColors.sageDark),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(barcode,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: .8,
                                    color: AnamelColors.brown))),
                        const Icon(Icons.open_in_new_rounded,
                            size: 14, color: AnamelColors.sageDark)
                      ])))),
          Expanded(
              flex: 2,
              child: Container(
                  margin: const EdgeInsets.only(left: 12),
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                          color: customer.points > 0
                              ? AnamelColors.sage.withValues(alpha: .25)
                              : AnamelColors.ivory,
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.stars_rounded,
                            size: 16,
                            color: customer.points > 0
                                ? Colors.amber.shade700
                                : Colors.grey.shade400),
                        const SizedBox(width: 5),
                        Text('${customer.points} نقطة',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: customer.points > 0
                                    ? AnamelColors.sageDark
                                    : Colors.grey.shade600))
                      ])))),
          Expanded(
              flex: 2,
              child: Text('${customer.totalSpent.toStringAsFixed(1)} دج',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AnamelColors.brown))),
          Expanded(
              flex: 2,
              child: Text(formatDate(customer.lastVisit),
                  style: TextStyle(
                      fontSize: 12,
                      color: AnamelColors.brown.withValues(alpha: .75)))),
          SizedBox(
              width: 170,
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(
                    tooltip: 'طباعة الباركود',
                    onPressed: () =>
                        BarcodePrintService.printCustomer(customer),
                    icon: const Icon(Icons.print_rounded,
                        color: AnamelColors.sageDark, size: 20),
                    style: IconButton.styleFrom(
                        backgroundColor:
                            AnamelColors.sage.withValues(alpha: .15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)))),
                const SizedBox(width: 6),
                IconButton(
                    tooltip: 'تعديل بيانات العميل',
                    onPressed: () => onEdit(customer),
                    icon: const Icon(Icons.edit_outlined,
                        color: AnamelColors.brown, size: 19),
                    style: IconButton.styleFrom(
                        backgroundColor: AnamelColors.ivory,
                        side: const BorderSide(color: AnamelColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)))),
                const SizedBox(width: 6),
                IconButton(
                    tooltip: 'حذف العميل',
                    onPressed: () => onDelete(customer),
                    icon: Icon(Icons.delete_outline_rounded,
                        color: Colors.red.shade400, size: 20),
                    style: IconButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))))
              ]))
        ]));
  }
}
