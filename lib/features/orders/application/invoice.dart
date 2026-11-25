import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/config/env.dart';
import '../../../core/config/store_settings.dart';
import '../domain/order.dart';

/// Hands a finished invoice PDF to the phone, which offers to save it to
/// Files or Drive, or send it on. Replaced in tests.
typedef InvoiceSharer = Future<void> Function(Uint8List bytes, String name);

final invoiceSharerProvider = Provider<InvoiceSharer>(
  (ref) => (bytes, name) => Printing.sharePdf(bytes: bytes, filename: name),
);

/// The file name for [order]'s invoice, e.g. `mart2door-invoice-2D1002.pdf`.
String invoiceFileName(Order order) =>
    'mart2door-invoice-${order.displayId.replaceAll('#', '')}.pdf';

/// Rupees for a PDF. The built-in PDF fonts have no rupee sign, so
/// amounts are written "Rs. 1,234" or "Rs. 1,234.50".
String invoiceMoney(int paise) {
  final negative = paise < 0;
  final abs = paise.abs();
  final rupees = (abs ~/ 100).toString();
  final buffer = StringBuffer();
  // Indian grouping: last three digits, then twos.
  final head = rupees.length > 3 ? rupees.substring(0, rupees.length - 3) : '';
  final tail = rupees.length > 3 ? rupees.substring(rupees.length - 3) : rupees;
  for (var i = 0; i < head.length; i++) {
    if (i > 0 && (head.length - i) % 2 == 0) buffer.write(',');
    buffer.write(head[i]);
  }
  if (head.isNotEmpty) buffer.write(',');
  buffer.write(tail);
  final fraction = abs % 100;
  if (fraction != 0) buffer.write('.${fraction.toString().padLeft(2, '0')}');
  return '${negative ? '- ' : ''}Rs. $buffer';
}

String _date(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct',
    'Nov', 'Dec',
  ];
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${months[d.month - 1]} ${d.year}, '
      '$hour:$minute ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// Lines of the bill below the items, in order: label and amount.
List<(String, int)> invoiceLines(Order order) => [
      ('Item total', order.subtotalPaise),
      (
        order.isCourier ? 'Delivery charge' : 'Delivery fee',
        order.deliveryFeePaise,
      ),
      if (order.handlingFeePaise > 0)
        ('Handling charge', order.handlingFeePaise),
      if (order.rainFeePaise > 0) ('Rain charge', order.rainFeePaise),
      if (order.couponDiscountPaise > 0)
        (
          'Coupon ${order.couponCode ?? ''}'.trim(),
          -order.couponDiscountPaise,
        ),
    ];

/// Builds the invoice for [order] as a one-page A4 PDF: the store, the
/// order, who it was delivered to, every item, the charges and what was
/// paid and how.
Future<Uint8List> buildInvoicePdf(Order order, StoreSettings store) async {
  final doc = pw.Document(
    title: 'Invoice ${order.displayId}',
    author: AppConfig.appName,
  );
  final maroon = PdfColor.fromHex('#800020');
  final muted = PdfColor.fromHex('#6B5B60');
  final line = PdfColor.fromHex('#E6D5D9');
  final storeName =
      store.storeName.isEmpty ? AppConfig.appName : store.storeName;

  pw.Widget label(String text) => pw.Text(
        text.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 8,
          color: muted,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 0.6,
        ),
      );
  pw.Widget amountRow(String name, int paise, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              name,
              style: pw.TextStyle(
                fontSize: bold ? 12 : 10,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
            pw.Text(
              paise == 0 && !bold ? 'Free' : invoiceMoney(paise),
              style: pw.TextStyle(
                fontSize: bold ? 12 : 10,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ],
        ),
      );

  final paid = order.paymentStatus == PaymentStatus.paid;
  final payment = switch (order.paymentMethod) {
    PaymentMethod.online => paid ? 'Paid online' : 'Online payment pending',
    PaymentMethod.cod => order.status == OrderStatus.delivered
        ? 'Paid on delivery'
        : 'To be paid on delivery',
  };

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      storeName,
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: maroon,
                      ),
                    ),
                    if (store.storeAddress.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 3),
                        child: pw.Text(
                          store.storeAddress,
                          style: pw.TextStyle(fontSize: 9.5, color: muted),
                        ),
                      ),
                    if (store.supportEmail.isNotEmpty)
                      pw.Text(
                        store.supportEmail,
                        style: pw.TextStyle(fontSize: 9.5, color: muted),
                      ),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'INVOICE',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Order ${order.displayId}',
                    style: const pw.TextStyle(fontSize: 10.5),
                  ),
                  pw.Text(
                    _date(order.createdAt),
                    style: pw.TextStyle(fontSize: 9.5, color: muted),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Divider(color: line, thickness: 1),
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    label('Delivered to'),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      order.address.name,
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      [
                        order.address.line1,
                        if (order.address.landmark.isNotEmpty)
                          order.address.landmark,
                        order.address.pincode,
                      ].join(', '),
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      order.address.phone,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 24),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  label('Payment'),
                  pw.SizedBox(height: 3),
                  pw.Text(payment, style: const pw.TextStyle(fontSize: 10.5)),
                  if (order.paymentId != null)
                    pw.Text(
                      'Ref ${order.paymentId}',
                      style: pw.TextStyle(fontSize: 9, color: muted),
                    ),
                  pw.SizedBox(height: 6),
                  label('Delivery'),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    order.isCourier ? 'Outstation' : 'Instant',
                    style: const pw.TextStyle(fontSize: 10.5),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: const ['No.', 'Item', 'Pack', 'Qty', 'Price', 'Amount'],
            data: [
              for (final (i, item) in order.items.indexed)
                [
                  '${i + 1}',
                  item.name,
                  item.unit,
                  '${item.quantity}',
                  invoiceMoney(item.pricePaise),
                  invoiceMoney(item.lineTotalPaise),
                ],
            ],
            headerStyle: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(color: maroon),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(color: line, width: 0.6),
              bottom: pw.BorderSide(color: line, width: 0.6),
            ),
            columnWidths: const {
              0: pw.FixedColumnWidth(28),
              1: pw.FlexColumnWidth(4),
              2: pw.FlexColumnWidth(1.6),
              3: pw.FixedColumnWidth(34),
              4: pw.FlexColumnWidth(1.6),
              5: pw.FlexColumnWidth(1.8),
            },
            headerAlignments: const {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
            },
            cellAlignments: const {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
            },
          ),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 230,
              child: pw.Column(
                children: [
                  for (final (name, paise) in invoiceLines(order))
                    amountRow(name, paise),
                  pw.Divider(color: line, thickness: 0.8),
                  amountRow('Total', order.totalPaise, bold: true),
                  if (order.walletAppliedPaise > 0) ...[
                    amountRow('Paid from m2d wallet',
                        -order.walletAppliedPaise),
                    amountRow(
                      paid || order.status == OrderStatus.delivered
                          ? 'Paid'
                          : 'To pay',
                      order.payablePaise,
                      bold: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
          pw.Spacer(),
          pw.Divider(color: line, thickness: 0.8),
          pw.Text(
            'Thank you for shopping with $storeName. This is a computer-'
            'generated invoice and needs no signature.',
            style: pw.TextStyle(fontSize: 8.5, color: muted),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}
