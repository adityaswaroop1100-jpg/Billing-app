import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/bill.dart';
import '../services/db_helper.dart';
import '../widgets/bill_receipt_widget.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final _dbHelper = DatabaseHelper.instance;
  List<Bill> _allBills = [];
  bool _isLoading = true;

  // Stats variables
  double _todayTotalSales = 0.0;
  int _todayBillCount = 0;
  String _todayTopItem = 'None';
  String _shopName = 'Kaveri Sweets';
  String _shopAddress = 'SR Dalmai Road, Madhupur, Deoghar';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final bills = await _dbHelper.getBills();
    final name = await _dbHelper.getSetting('shop_name', 'Kaveri Sweets');
    final address = await _dbHelper.getSetting('shop_address', 'SR Dalmai Road, Madhupur, Deoghar');

    setState(() {
      _allBills = bills;
      _shopName = name;
      _shopAddress = address;
      _calculateTodayStats(bills);
      _isLoading = false;
    });
  }

  void _calculateTodayStats(List<Bill> bills) {
    final now = DateTime.now();
    final todayBills = bills.where((bill) {
      return bill.dateTime.year == now.year &&
          bill.dateTime.month == now.month &&
          bill.dateTime.day == now.day;
    }).toList();

    _todayBillCount = todayBills.length;
    _todayTotalSales = todayBills.fold(0.0, (sum, b) => sum + b.totalAmount);

    // Calculate top item
    final itemCounts = <String, double>{};
    for (var bill in todayBills) {
      for (var item in bill.items) {
        itemCounts[item.name] = (itemCounts[item.name] ?? 0.0) + item.quantity;
      }
    }

    if (itemCounts.isNotEmpty) {
      String topItem = '';
      double maxQty = -1.0;
      itemCounts.forEach((name, qty) {
        if (qty > maxQty) {
          maxQty = qty;
          topItem = name;
        }
      });
      _todayTopItem = topItem;
    } else {
      _todayTopItem = 'N/A';
    }
  }

  void _viewBillDetails(Bill bill) {
    final boundaryKey = GlobalKey();

    showDialog(
      context: context,
      builder: (context) {
        bool isSharing = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFFFFDF9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              contentPadding: const EdgeInsets.all(12),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Render the exact receipt widget
                    BillReceiptWidget(
                      bill: bill,
                      boundaryKey: boundaryKey,
                      shopName: _shopName,
                      shopAddress: _shopAddress,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Close',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE05A10),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          onPressed: isSharing
                              ? null
                              : () async {
                                  setDialogState(() => isSharing = true);
                                  
                                  // Capture PNG bytes
                                  final pngBytes = await capturePngFromKey(boundaryKey);
                                  if (pngBytes != null) {
                                    // Save temporarily to share
                                    final tempDir = await getTemporaryDirectory();
                                    final file = await File('${tempDir.path}/KaveriSweets_Bill_${bill.id ?? DateTime.now().millisecondsSinceEpoch}.png').create();
                                    await file.writeAsBytes(pngBytes);

                                    // Trigger native share sheet
                                    final text = 'Bill from $_shopName: ₹${bill.totalAmount.toStringAsFixed(1)}';
                                    await Share.shareXFiles(
                                      [XFile(file.path)],
                                      text: text,
                                      subject: 'Kaveri Sweets Bill',
                                    );
                                  } else {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Failed to generate receipt image.')),
                                      );
                                    }
                                  }
                                  setDialogState(() => isSharing = false);
                                },
                          icon: isSharing 
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.share, size: 20),
                          label: Text(
                            isSharing ? 'Sharing...' : 'Re-share Bill',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 1);
    final dateFormatter = DateFormat('dd MMM, hh:mm a');

    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      appBar: AppBar(
        title: const Text(
          'Sales History & Reports',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFE05A10),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh Sales',
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFFE05A10))))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- TODAY'S SUMMARY CARDS ---
                  const Text(
                    "Today's Business",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8B2500),
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  // Summary Layout
                  Row(
                    children: [
                      // Total Sales Card
                      Expanded(
                        child: Card(
                          color: const Color(0xFFFFFDF9),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Color(0xFFD4AF37), width: 1),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                            child: Column(
                              children: [
                                const Text('Total Sales', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 6),
                                Text(
                                  currencyFormatter.format(_todayTotalSales),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFE05A10)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      
                      // Bills Count Card
                      Expanded(
                        child: Card(
                          color: const Color(0xFFFFFDF9),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Color(0xFFD4AF37), width: 1),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                            child: Column(
                              children: [
                                const Text('Total Bills', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 6),
                                Text(
                                  '$_todayBillCount',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF8B2500)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Top Product Card
                      Expanded(
                        child: Card(
                          color: const Color(0xFFFFFDF9),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Color(0xFFD4AF37), width: 1),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                            child: Column(
                              children: [
                                const Text('Top Sweet', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 6),
                                Text(
                                  _todayTopItem,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF4A2711)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // --- TRANSACTIONS LIST ---
                  const Text(
                    "All Bills",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8B2500),
                    ),
                  ),
                  const SizedBox(height: 10),

                  _allBills.isEmpty
                      ? const Card(
                          color: Color(0xFFFFFDF9),
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Center(
                              child: Text(
                                'No bills generated yet.',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _allBills.length,
                          itemBuilder: (context, index) {
                            final bill = _allBills[index];
                            final totalItemsCount = bill.items.fold<double>(
                                0, (sum, i) => sum + (i.priceType == 'piece' ? i.quantity : 1));
                            
                            return Card(
                              color: const Color(0xFFFFFDF9),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: bill.paymentMode == 'UPI'
                                      ? Colors.green.withOpacity(0.1)
                                      : bill.paymentMode == 'Cash'
                                          ? Colors.blue.withOpacity(0.1)
                                          : Colors.orange.withOpacity(0.1),
                                  child: Icon(
                                    bill.paymentMode == 'UPI'
                                        ? Icons.qr_code
                                        : bill.paymentMode == 'Cash'
                                            ? Icons.money
                                            : Icons.error_outline,
                                    color: bill.paymentMode == 'UPI'
                                        ? Colors.green
                                        : bill.paymentMode == 'Cash'
                                            ? Colors.blue
                                            : Colors.orange,
                                  ),
                                ),
                                title: Text(
                                  currencyFormatter.format(bill.totalAmount),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4A2711),
                                  ),
                                ),
                                subtitle: Text(
                                  '${dateFormatter.format(bill.dateTime)} • ${totalItemsCount.toInt()} items • ${bill.paymentMode}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                trailing: const Icon(Icons.chevron_right, size: 28, color: Color(0xFF8B2500)),
                                onTap: () => _viewBillDetails(bill),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }
}
