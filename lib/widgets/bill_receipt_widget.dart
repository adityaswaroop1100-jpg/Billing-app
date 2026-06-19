import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';

// ─── Colours matching the premium template ───────────────────────────────────
const _cream = Color(0xFFFBF4E2);          // warm cream background
const _navy = Color(0xFF1B2B4B);           // dark navy header / accents
const _gold = Color(0xFFC9973A);           // gold borders & ornaments
const _goldLight = Color(0xFFE5C97A);      // lighter gold highlight
const _darkBrown = Color(0xFF3D1F00);      // deep brown text
const _rowAlt = Color(0xFFF5EDD8);         // alternating row tint

// ─── Number → Words (Indian system) ──────────────────────────────────────────
String numberToWords(double number) {
  int amount = number.floor();
  if (amount == 0) return 'Rupees Zero Only';

  final units = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight',
    'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen',
    'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'
  ];
  final tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

  String convert(int n) {
    if (n < 20) return units[n];
    if (n < 100) return '${tens[n ~/ 10]}${n % 10 > 0 ? ' ${units[n % 10]}' : ''}';
    if (n < 1000) return '${units[n ~/ 100]} Hundred${n % 100 > 0 ? ' and ${convert(n % 100)}' : ''}';
    if (n < 100000) return '${convert(n ~/ 1000)} Thousand${n % 1000 > 0 ? ' ${convert(n % 1000)}' : ''}';
    if (n < 10000000) return '${convert(n ~/ 100000)} Lakh${n % 100000 > 0 ? ' ${convert(n % 100000)}' : ''}';
    return '';
  }

  return 'Rupees ${convert(amount)} Only';
}

// ─── Corner ornament painter ──────────────────────────────────────────────────
class _CornerPainter extends CustomPainter {
  final Color color;
  const _CornerPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final s = size.width; // square
    // L-shaped corner lines
    canvas.drawLine(Offset(0, s * 0.4), Offset(0, 0), paint);
    canvas.drawLine(Offset(0, 0), Offset(s * 0.4, 0), paint);
    // Inner flourish dots
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(Offset(s * 0.4, s * 0.12), 2.5, paint);
    canvas.drawCircle(Offset(s * 0.12, s * 0.4), 2.5, paint);
    // Diagonal dot
    canvas.drawCircle(Offset(s * 0.22, s * 0.22), 3, paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => old.color != color;
}

// ─── Decorative corner widget ─────────────────────────────────────────────────
Widget _corner(bool flipH, bool flipV, {double size = 36}) {
  Widget w = CustomPaint(
    size: Size(size, size),
    painter: _CornerPainter(_gold),
  );
  if (flipH || flipV) {
    w = Transform.scale(scaleX: flipH ? -1 : 1, scaleY: flipV ? -1 : 1, child: w);
  }
  return w;
}

// ─── Gold divider ─────────────────────────────────────────────────────────────
Widget _goldDivider({double v = 12}) => Padding(
      padding: EdgeInsets.symmetric(vertical: v),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: _gold)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: _gold, shape: BoxShape.circle),
            ),
          ),
          Container(width: 20, height: 1, color: _gold),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: _gold, shape: BoxShape.circle),
            ),
          ),
          Container(width: 20, height: 1, color: _gold),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: _gold, shape: BoxShape.circle),
            ),
          ),
          Expanded(child: Container(height: 1, color: _gold)),
        ],
      ),
    );

// ─── Main receipt widget ──────────────────────────────────────────────────────
class BillReceiptWidget extends StatelessWidget {
  final Bill bill;
  final GlobalKey boundaryKey;
  final String shopName;
  final String shopAddress;

  const BillReceiptWidget({
    super.key,
    required this.bill,
    required this.boundaryKey,
    required this.shopName,
    required this.shopAddress,
  });

  @override
  Widget build(BuildContext context) {
    final cf = NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: 1);
    final df = DateFormat('dd-MM-yyyy  hh:mm a');

    return RepaintBoundary(
      key: boundaryKey,
      child: Container(
        width: 620,
        decoration: BoxDecoration(
          color: _cream,
          // Double-line gold outer border
          border: Border.all(color: _gold, width: 3),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Container(
          // Inner border
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            border: Border.all(color: _gold.withOpacity(0.55), width: 1),
            borderRadius: BorderRadius.circular(2),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Ornamental corners ─────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _corner(false, false),
                  _corner(true, false),
                ],
              ),

              // ── HEADER ROW ─────────────────────────────────────────────
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left: motto
                    Expanded(
                      flex: 28,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            decoration: BoxDecoration(
                              border: Border.symmetric(
                                horizontal: BorderSide(color: _gold, width: 1.2),
                              ),
                            ),
                            child: Text(
                              'Delight in\nEvery Bite',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                fontFamily: 'serif',
                                fontSize: 15,
                                height: 1.6,
                                fontWeight: FontWeight.w600,
                                color: _darkBrown,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Center: Logo (prominent, not clipped oval)
                    Expanded(
                      flex: 44,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _gold.withOpacity(0.35),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/logo.png',
                                width: 110,
                                height: 110,
                                fit: BoxFit.cover,
                                errorBuilder: (context, e, s) => Image.asset(
                                  'assets/logo.jpg',
                                  width: 110,
                                  height: 110,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 110,
                                    height: 110,
                                    decoration: const BoxDecoration(
                                      color: _navy,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.store, color: Colors.white, size: 48),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Right: vertical gold divider + address
                    Container(width: 1.2, height: 90, color: _gold.withOpacity(0.7)),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 38,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _addrRow(Icons.location_on, 'SR Dalmia Road,\nMadhupur, Deoghar'),
                          const SizedBox(height: 6),
                          _addrRow(Icons.phone, '6203490478'),
                          const SizedBox(height: 6),
                          _addrRow(Icons.access_time, '9:00 AM – 9:00 PM\n(All Days)'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Gold divider ───────────────────────────────────────────
              _goldDivider(v: 10),

              // ── BILL title ─────────────────────────────────────────────
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: _gold, width: 1.8),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    'B I L L',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                      color: _navy,
                      fontFamily: 'serif',
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Bill No & Date ─────────────────────────────────────────
              Row(
                children: [
                  Text(
                    'Bill No. :  ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _darkBrown),
                  ),
                  Expanded(
                    flex: 4,
                    child: Container(
                      height: 1,
                      color: _darkBrown.withOpacity(0.45),
                      margin: const EdgeInsets.only(bottom: 2),
                    ),
                  ),
                  Text(
                    '   ${bill.id ?? ""}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _navy),
                  ),
                  const Spacer(),
                  Text(
                    'Date :  ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _darkBrown),
                  ),
                  Expanded(
                    flex: 5,
                    child: Container(
                      height: 1,
                      color: _darkBrown.withOpacity(0.45),
                      margin: const EdgeInsets.only(bottom: 2),
                    ),
                  ),
                  Text(
                    '   ${df.format(bill.dateTime)}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _navy),
                  ),
                ],
              ),

              _goldDivider(v: 10),

              // ── ITEMS TABLE ────────────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Table(
                  border: TableBorder.all(
                    color: _gold.withOpacity(0.5),
                    width: 0.8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  columnWidths: const {
                    0: FlexColumnWidth(1.1),   // S.No.
                    1: FlexColumnWidth(5.0),   // Particulars
                    2: FlexColumnWidth(2.2),   // Qty
                    3: FlexColumnWidth(2.2),   // Rate
                    4: FlexColumnWidth(2.5),   // Amount
                  },
                  children: [
                    // Header row
                    TableRow(
                      decoration: const BoxDecoration(color: _navy),
                      children: [
                        _th('S. No.', TextAlign.center),
                        _th('Particulars', TextAlign.left),
                        _th('Qty.', TextAlign.center),
                        _th('Rate (₹)', TextAlign.center),
                        _th('Amount (₹)', TextAlign.right),
                      ],
                    ),

                    // Data rows
                    ...List.generate(bill.items.length, (i) {
                      final item = bill.items[i];
                      final isAlt = i % 2 == 1;
                      return TableRow(
                        decoration: BoxDecoration(
                          color: isAlt ? _rowAlt : _cream,
                        ),
                        children: [
                          _td('${i + 1}', TextAlign.center),
                          _tdBold(item.name, TextAlign.left),
                          _td(item.quantityDisplay, TextAlign.center),
                          _td(cf.format(item.rate), TextAlign.center),
                          _tdBold(cf.format(item.totalPrice), TextAlign.right),
                        ],
                      );
                    }),

                    // Minimum 10 rows for template look
                    ...List.generate(
                      bill.items.length < 10 ? 10 - bill.items.length : 0,
                      (i) => TableRow(
                        decoration: BoxDecoration(
                          color: (bill.items.length + i) % 2 == 1 ? _rowAlt : _cream,
                        ),
                        children: [
                          _td('${bill.items.length + i + 1}', TextAlign.center),
                          _td('', TextAlign.left),
                          _td('', TextAlign.center),
                          _td('', TextAlign.center),
                          _td('', TextAlign.right),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── BOTTOM SECTION ─────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left: Thank You box
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: _gold, width: 1.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Thank You!',
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: _navy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(width: 60, height: 1, color: _gold),
                          const SizedBox(height: 6),
                          Text(
                            'For choosing Kaveri Sweets.\nWe truly appreciate your trust.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              color: _darkBrown.withOpacity(0.75),
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Center: Logo watermark
                  Expanded(
                    flex: 3,
                    child: Opacity(
                      opacity: 0.55,
                      child: Image.asset(
                        'assets/logo.png',
                        height: 80,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/logo.jpg',
                          height: 80,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.local_dining, color: _gold, size: 40),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Right: Totals table
                  Expanded(
                    flex: 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Table(
                        border: TableBorder.all(
                          color: _gold.withOpacity(0.5),
                          width: 0.8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        columnWidths: const {
                          0: FlexColumnWidth(3),
                          1: FlexColumnWidth(2),
                        },
                        children: [
                          _totalRow('Total Amount', cf.format(bill.subtotal), navy: true),
                          _totalRow('Discount', '- ${cf.format(bill.discount)}', navy: false),
                          _totalRow('Total', cf.format(bill.totalAmount), navy: true, isFinal: true),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Amount in Words ────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: _gold.withOpacity(0.5), width: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Text(
                      'Amount in Words :  ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: _darkBrown,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        numberToWords(bill.totalAmount),
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 11,
                          color: _navy,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Authorised Signature ───────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(width: 140, height: 30),
                      Container(width: 140, height: 1, color: _darkBrown.withOpacity(0.5)),
                      const SizedBox(height: 4),
                      Text(
                        'Authorised Sign.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _darkBrown,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ── Ornamental bottom corners ──────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _corner(false, true),
                  _corner(true, true),
                ],
              ),

              // ── FOOTER ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 24, height: 1.5, color: _gold),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_right, color: _gold, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'PURE INGREDIENTS  •  TRADITIONAL RECIPES  •  TIMELESS TASTE',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: _gold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_left, color: _gold, size: 14),
                    const SizedBox(width: 6),
                    Container(width: 24, height: 1.5, color: _gold),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helper builders ─────────────────────────────────────────────────────────

  static Widget _addrRow(IconData icon, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: _gold),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _darkBrown,
                height: 1.45,
              ),
            ),
          ),
        ],
      );

  static TableRow _totalRow(String label, String value, {required bool navy, bool isFinal = false}) {
    final bg = navy ? _navy : _cream;
    final fg = navy ? Colors.white : _darkBrown;
    final fs = isFinal ? 13.0 : 11.0;
    return TableRow(
      decoration: BoxDecoration(color: bg),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: fs,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(
            '₹  $value',
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: fs,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ),
      ],
    );
  }

  static Widget _th(String t, TextAlign align) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        child: Text(
          t,
          textAlign: align,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
      );

  static Widget _td(String t, TextAlign align) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Text(
          t,
          textAlign: align,
          style: const TextStyle(fontSize: 12, color: _darkBrown),
        ),
      );

  static Widget _tdBold(String t, TextAlign align) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Text(
          t,
          textAlign: align,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _darkBrown,
          ),
        ),
      );
}

// ─── Capture PNG helper ───────────────────────────────────────────────────────
Future<Uint8List?> capturePngFromKey(GlobalKey boundaryKey) async {
  try {
    RenderRepaintBoundary? boundary =
        boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  } catch (e) {
    debugPrint('Error rendering screenshot: $e');
    return null;
  }
}
