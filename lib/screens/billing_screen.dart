import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../models/bill.dart';
import '../models/item.dart';
import '../services/db_helper.dart';
import '../widgets/bill_receipt_widget.dart';
import 'sales_history_screen.dart';
import 'settings_screen.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final _dbHelper = DatabaseHelper.instance;
  final _receiptBoundaryKey = GlobalKey();

  List<Item> _allItems = [];
  final List<BillItem> _cartItems = [];
  bool _isLoading = true;

  // Shop details
  String _shopName = 'Kaveri Sweets';
  String _shopAddress = 'SR Dalmai Road, Madhupur, Deoghar';
  String _upiId = 'kaverisweets@upi';

  // State controls
  String _paymentMode = 'Cash'; // 'Cash', 'UPI'
  bool _showUpiQr = false;
  bool _isSharing = false;
  double _discount = 0.0;
  final _discountController = TextEditingController(text: '0');

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadShopConfigAndItems();
  }

  Future<void> _loadShopConfigAndItems() async {
    setState(() => _isLoading = true);
    final name = await _dbHelper.getSetting('shop_name', 'Kaveri Sweets');
    final address = await _dbHelper.getSetting('shop_address', 'SR Dalmai Road, Madhupur, Deoghar');
    final upi = await _dbHelper.getSetting('upi_id', 'kaverisweets@upi');
    final items = await _dbHelper.getItems();

    setState(() {
      _shopName = name;
      _shopAddress = address;
      _upiId = upi;
      _allItems = items;
      _isLoading = false;
    });
  }

  double get _totalAmount {
    return _cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  // --- ADD ITEM TO CART LOGIC ---

  void _addPieceItemToCart(Item item) {
    setState(() {
      final existingIndex = _cartItems.indexWhere((i) => i.name == item.name && i.priceType == 'piece');
      if (existingIndex >= 0) {
        final existingItem = _cartItems[existingIndex];
        final newQty = existingItem.quantity + 1;
        _cartItems[existingIndex] = BillItem(
          name: item.name,
          priceType: 'piece',
          rate: item.price,
          quantity: newQty,
          totalPrice: newQty * item.price,
        );
      } else {
        _cartItems.add(BillItem(
          name: item.name,
          priceType: 'piece',
          rate: item.price,
          quantity: 1,
          totalPrice: item.price,
        ));
      }
    });
  }

  void _showWeightInputDialog(Item item) {
    double grams = 500; // Default suggestions
    final customGramsController = TextEditingController(text: '500');
    final dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void setWeightPreset(double value) {
              setDialogState(() {
                grams = value;
                customGramsController.text = value.toInt().toString();
              });
            }

            return AlertDialog(
              backgroundColor: const Color(0xFFFFFDF9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Enter Weight for ${item.name}',
                style: const TextStyle(color: Color(0xFF8B2500), fontWeight: FontWeight.bold),
              ),
              content: Form(
                key: dialogFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Weight Presets Buttons
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildPresetButton('250g', () => setWeightPreset(250)),
                        _buildPresetButton('500g', () => setWeightPreset(500)),
                        _buildPresetButton('1kg', () => setWeightPreset(1000)),
                        _buildPresetButton('1.5kg', () => setWeightPreset(1500)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Custom Weight Field
                    TextFormField(
                      controller: customGramsController,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Weight in Grams (g)',
                        labelStyle: TextStyle(color: Color(0xFF8B2500)),
                        suffixText: ' g',
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFE05A10)),
                        ),
                      ),
                      onChanged: (val) {
                        final parsed = double.tryParse(val);
                        if (parsed != null) {
                          setDialogState(() => grams = parsed);
                        }
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Enter grams';
                        final val = double.tryParse(value);
                        if (val == null || val <= 0) return 'Enter valid weight';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    
                    // Live Price Preview
                    Text(
                      'Price: ₹ ${(grams / 1000 * item.price).toStringAsFixed(1)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE05A10)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE05A10),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    if (dialogFormKey.currentState!.validate()) {
                      final finalGrams = double.parse(customGramsController.text.trim());
                      final price = (finalGrams / 1000) * item.price;
                      
                      setState(() {
                        // Weight items are stacked if they have the exact same price and name
                        final existingIndex = _cartItems.indexWhere((i) => i.name == item.name && i.priceType == 'weight');
                        if (existingIndex >= 0) {
                          final existingItem = _cartItems[existingIndex];
                          final newQty = existingItem.quantity + finalGrams;
                          _cartItems[existingIndex] = BillItem(
                            name: item.name,
                            priceType: 'weight',
                            rate: item.price,
                            quantity: newQty,
                            totalPrice: (newQty / 1000) * item.price,
                          );
                        } else {
                          _cartItems.add(BillItem(
                            name: item.name,
                            priceType: 'weight',
                            rate: item.price,
                            quantity: finalGrams,
                            totalPrice: price,
                          ));
                        }
                      });

                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Add to Bill', style: TextStyle(fontSize: 16)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPresetButton(String label, VoidCallback onPressed) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFFDF9),
          foregroundColor: const Color(0xFF8B2500),
          side: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }

  // --- ASSORTED BOX BUILDER LOGIC ---

  void _showAssortedBoxBuilder() {
    double totalWeight = 1000; // Default 1kg
    final weightController = TextEditingController(text: '1000');
    final selectedSweets = <Item, bool>{};

    // Initialize all weight sweets
    final weightItems = _allItems.where((i) => i.priceType == 'weight').toList();
    for (var sweet in weightItems) {
      selectedSweets[sweet] = false;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final activeSweets = selectedSweets.entries.where((e) => e.value).map((e) => e.key).toList();
            
            // Calculate equal split weight and total price
            double splitWeight = activeSweets.isNotEmpty ? totalWeight / activeSweets.length : 0.0;
            double blendedPrice = 0.0;
            for (var sweet in activeSweets) {
              blendedPrice += (splitWeight / 1000) * sweet.price;
            }

            return AlertDialog(
              backgroundColor: const Color(0xFFFFFDF9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'Assorted Sweets Box',
                style: TextStyle(color: Color(0xFF8B2500), fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Total Box Weight Input
                    TextFormField(
                      controller: weightController,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Box Size (Total Weight in grams)',
                        labelStyle: TextStyle(color: Color(0xFF8B2500)),
                        suffixText: ' g',
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFE05A10)),
                        ),
                      ),
                      onChanged: (val) {
                        final parsed = double.tryParse(val);
                        if (parsed != null) {
                          setDialogState(() => totalWeight = parsed);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    // Box Presets
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            setDialogState(() {
                              totalWeight = 500;
                              weightController.text = '500';
                            });
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFFDF9), foregroundColor: const Color(0xFF8B2500)),
                          child: const Text('500 g'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setDialogState(() {
                              totalWeight = 1000;
                              weightController.text = '1000';
                            });
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFFDF9), foregroundColor: const Color(0xFF8B2500)),
                          child: const Text('1 kg'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Select Sweets to Mix:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8B2500)),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // List of weight items to check
                    Expanded(
                      child: ListView.builder(
                        itemCount: weightItems.length,
                        itemBuilder: (context, index) {
                          final sweet = weightItems[index];
                          return CheckboxListTile(
                            title: Text(sweet.name, style: const TextStyle(fontSize: 14)),
                            subtitle: Text('₹${sweet.price}/kg', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            value: selectedSweets[sweet],
                            activeColor: const Color(0xFFE05A10),
                            onChanged: (val) {
                              setDialogState(() {
                                selectedSweets[sweet] = val ?? false;
                              });
                            },
                          );
                        },
                      ),
                    ),
                    
                    const Divider(color: Color(0xFFE05A10)),
                    const SizedBox(height: 8),

                    // Blended Summary
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sweets selected: ${activeSweets.length}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Total Price: ₹ ${blendedPrice.toStringAsFixed(1)}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFE05A10)),
                        ),
                      ],
                    ),
                    if (activeSweets.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          '(${splitWeight.toInt()}g of each sweet)',
                          style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE05A10),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: activeSweets.isEmpty
                      ? null
                      : () {
                          // Assemble final Assorted Box Item name
                          final names = activeSweets.map((s) => s.name).join(', ');
                          final boxName = 'Assorted Box ($names)';

                          setState(() {
                            _cartItems.add(BillItem(
                              name: boxName,
                              priceType: 'weight',
                              rate: blendedPrice / (totalWeight / 1000), // Blended rate per kg
                              quantity: totalWeight,
                              totalPrice: blendedPrice,
                            ));
                          });

                          Navigator.pop(context);
                        },
                  child: const Text('Add Box', style: TextStyle(fontSize: 16)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- SAVE & SHARE BILL LOGIC ---

  Future<void> _shareBill() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot share an empty bill!')),
      );
      return;
    }

    setState(() => _isSharing = true);

    try {
      // 1. Save bill details locally to DB
      final bill = Bill(
        items: List.from(_cartItems),
        subtotal: _totalAmount,
        discount: _discount,
        totalAmount: _totalAmount - _discount,
        paymentMode: _paymentMode,
        dateTime: DateTime.now(),
      );

      final id = await _dbHelper.insertBill(bill);

      // Force UI updates to render receipt boundary key accurately before capturing
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 300));

      // 2. Capture boundary widget as PNG
      final pngBytes = await capturePngFromKey(_receiptBoundaryKey);
      if (pngBytes != null) {
        // 3. Write image to a temporary file
        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/KaveriSweets_Bill_$id.png').create();
        await file.writeAsBytes(pngBytes);

        // 4. Share XFile using native Share Sheet
        final shareText = 'Kaveri Sweets Bill: Total ₹${(_totalAmount - _discount).toStringAsFixed(1)}';
        await Share.shareXFiles(
          [XFile(file.path)],
          text: shareText,
          subject: 'Kaveri Sweets Bill',
        );

        // 5. Clear cart after successful sharing
        setState(() {
          _cartItems.clear();
          _showUpiQr = false;
          _discount = 0.0;
          _discountController.text = '0';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bill saved and shared successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception("Capture returned null bytes");
      }
    } catch (e) {
      debugPrint("Error sharing bill: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share bill: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSharing = false);
    }
  }

  // --- ITEM CARD RENDERING ---

  Widget _buildItemTile(Item item) {
    final isWeight = item.priceType == 'weight';
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Card(
      color: const Color(0xFFFFFDF9),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isWeight ? const Color(0xFFE05A10) : const Color(0xFFD4AF37),
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: () {
          if (isWeight) {
            _showWeightInputDialog(item);
          } else {
            _addPieceItemToCart(item);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A2711),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${currencyFormatter.format(item.price)}${isWeight ? "/kg" : "/pc"}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isWeight ? const Color(0xFFE05A10) : const Color(0xFF8B2500),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isWeight ? const Color(0xFFFF9933).withOpacity(0.1) : const Color(0xFFFFBF00).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isWeight ? 'By Weight' : 'By Piece',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isWeight ? const Color(0xFFE05A10) : const Color(0xFF8B2500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 1);
    
    // Check orientation and screen width for responsiveness (Tablet split screen layout vs Phone overlay)
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 700;

    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFC9973A), width: 2),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/logo.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Image.asset(
                    'assets/logo.jpg',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.store, color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _shopName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'serif',
                    fontSize: 18,
                    letterSpacing: 0.5,
                  ),
                ),
                const Text(
                  'EST. 1968  •  Delight in Every Bite',
                  style: TextStyle(
                    color: Color(0xFFE5C97A),
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1B2B4B),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white, size: 28),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SalesHistoryScreen()),
              );
              _loadShopConfigAndItems(); // Reload configuration in case it changed
            },
            tooltip: 'Sales History',
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white, size: 28),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
              _loadShopConfigAndItems(); // Reload configuration updates
            },
            tooltip: 'Admin Settings',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFFE05A10))))
          : Stack(
              children: [
                // --- BACKGROUND HIDDEN RECEIPT WIDGET (for rendering PNG bytes) ---
                Offstage(
                  offstage: true,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        BillReceiptWidget(
                          bill: Bill(
                            items: _cartItems,
                            subtotal: _totalAmount,
                            discount: _discount,
                            totalAmount: _totalAmount - _discount,
                            paymentMode: _paymentMode,
                            dateTime: DateTime.now(),
                          ),
                          boundaryKey: _receiptBoundaryKey,
                          shopName: _shopName,
                          shopAddress: _shopAddress,
                        ),
                      ],
                    ),
                  ),
                ),

                // --- MAIN LAYOUT ---
                Row(
                  children: [
                    // Grid of Sweets (Takes full width on phone, 60% on tablet)
                    Expanded(
                      flex: isTablet ? 6 : 10,
                      child: Column(
                        children: [
                          // Header Quick Actions
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 52,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF8B2500),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: _showAssortedBoxBuilder,
                                      icon: const Icon(Icons.gif_box_outlined, size: 24),
                                      label: const Text('Make Custom Assorted Box', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Grid List of items
                          Expanded(
                            child: _allItems.isEmpty
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Text(
                                        'No sweets added yet.\nTap the Settings icon at the top right to customize your sweets catalog.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 16, color: Colors.grey),
                                      ),
                                    ),
                                  )
                                : GridView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: isTablet ? 3 : 2,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                      childAspectRatio: 1.15,
                                    ),
                                    itemCount: _allItems.length,
                                    itemBuilder: (context, index) {
                                      return _buildItemTile(_allItems[index]);
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),

                    // Cart Panel (Side Panel on Tablets, completely omitted here on phone and rendered as slide-up drawer)
                    if (isTablet) ...[
                      const VerticalDivider(width: 1, color: Colors.grey),
                      Expanded(
                        flex: 4,
                        child: Container(
                          color: const Color(0xFFFDFBF7),
                          padding: const EdgeInsets.all(12),
                          child: _buildCartPanelContent(context),
                        ),
                      ),
                    ]
                  ],
                ),
              ],
            ),
      
      // Bottom Sheet Drawer for Phone viewports (sliding panel)
      bottomNavigationBar: isTablet || _cartItems.isEmpty
          ? null
          : Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDF9),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, -2)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${_cartItems.length} Sweets Added',
                        style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Total: ${currencyFormatter.format(_totalAmount)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFE05A10)),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE05A10),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: const Color(0xFFFDFBF7),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (context) {
                          return StatefulBuilder(
                            builder: (context, setModalState) {
                              return DraggableScrollableSheet(
                                initialChildSize: 0.8,
                                minChildSize: 0.5,
                                maxChildSize: 0.95,
                                expand: false,
                                builder: (context, scrollController) {
                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    child: _buildCartPanelContent(context, scrollController, () {
                                      // Sync cart state changes
                                      setModalState(() {});
                                      setState(() {});
                                    }),
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                    icon: const Icon(Icons.shopping_cart),
                    label: const Text('View Bill Summary', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
    );
  }

  // --- REUSABLE CART SUMMARY BUILDER ---

  Widget _buildCartPanelContent(BuildContext context, [ScrollController? scrollController, VoidCallback? onCartUpdate]) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 1);
    final upiUrl = 'upi://pay?pa=$_upiId&pn=${Uri.encodeComponent(_shopName)}&am=${(_totalAmount - _discount).toStringAsFixed(1)}&cu=INR&tn=KaveriSweetsReceipt';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Running Bill',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF8B2500)),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _cartItems.clear();
                  _showUpiQr = false;
                  _discount = 0.0;
                  _discountController.text = '0';
                });
                if (onCartUpdate != null) onCartUpdate();
                if (scrollController != null) Navigator.pop(context); // Close sheet if open
              },
              icon: const Icon(Icons.delete_sweep, color: Colors.red),
              label: const Text('Clear All', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const Divider(color: Color(0xFFE05A10), thickness: 1),
        const SizedBox(height: 6),

        // Cart List View
        Expanded(
          child: _cartItems.isEmpty
              ? const Center(
                  child: Text(
                    'No items in bill yet.\nTap on sweets to add.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                )
              : ListView.separated(
                  controller: scrollController,
                  itemCount: _cartItems.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.black12),
                  itemBuilder: (context, index) {
                    final item = _cartItems[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          // Item Details
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A2711), fontSize: 14),
                                ),
                                Text(
                                  item.priceType == 'weight'
                                      ? 'Rate: ₹${item.rate.toStringAsFixed(0)}/kg'
                                      : 'Rate: ₹${item.rate.toStringAsFixed(0)}/pc',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),

                          // Quantity Adjuster Stepper
                          Expanded(
                            flex: 4,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (item.priceType == 'piece') ...[
                                  // Minus Button
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF8B2500)),
                                    onPressed: () {
                                      setState(() {
                                        if (item.quantity > 1) {
                                          _cartItems[index] = BillItem(
                                            name: item.name,
                                            priceType: 'piece',
                                            rate: item.rate,
                                            quantity: item.quantity - 1,
                                            totalPrice: (item.quantity - 1) * item.rate,
                                          );
                                        } else {
                                          _cartItems.removeAt(index);
                                        }
                                      });
                                      if (onCartUpdate != null) onCartUpdate();
                                    },
                                  ),
                                  Text(
                                    '${item.quantity.toInt()}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  // Plus Button
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, color: Color(0xFFE05A10)),
                                    onPressed: () {
                                      setState(() {
                                        _cartItems[index] = BillItem(
                                          name: item.name,
                                          priceType: 'piece',
                                          rate: item.rate,
                                          quantity: item.quantity + 1,
                                          totalPrice: (item.quantity + 1) * item.rate,
                                        );
                                      });
                                      if (onCartUpdate != null) onCartUpdate();
                                    },
                                  ),
                                ] else ...[
                                  // Weight Editor Action Button
                                  TextButton(
                                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                                    onPressed: () {
                                      // Re-trigger grams selection popup
                                      final rawItem = Item(name: item.name, priceType: 'weight', price: item.rate);
                                      _showWeightInputDialog(rawItem);
                                    },
                                    child: Text(
                                      item.quantityDisplay,
                                      style: const TextStyle(color: Color(0xFFE05A10), fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Price & Delete Action
                          Expanded(
                            flex: 3,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  currencyFormatter.format(item.totalPrice),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A2711), fontSize: 13),
                                ),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _cartItems.removeAt(index);
                                    });
                                    if (onCartUpdate != null) onCartUpdate();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),

        const Divider(color: Color(0xFFE05A10), thickness: 1.5),

        // Pricing breakdown
        if (_cartItems.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600)),
                Text(
                  currencyFormatter.format(_totalAmount),
                  style: const TextStyle(fontSize: 15, color: Color(0xFF4A2711), fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                const Expanded(
                  flex: 3,
                  child: Text('Discount (₹)', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      controller: _discountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF8B2500)),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE05A10))),
                      ),
                      onChanged: (val) {
                        double parsed = double.tryParse(val) ?? 0.0;
                        if (parsed < 0) parsed = 0.0;
                        if (parsed > _totalAmount) parsed = _totalAmount;
                        setState(() {
                          _discount = parsed;
                        });
                        if (onCartUpdate != null) onCartUpdate();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Bill', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF8B2500))),
              Text(
                currencyFormatter.format(_totalAmount - _discount),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFE05A10)),
              ),
            ],
          ),
        ),

        // Payment Mode Row Selector
        const SizedBox(height: 6),
        Row(
          children: [
            const Text(
              'Payment Mode:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF5A4A42)),
            ),
            const SizedBox(width: 8),
            // Cash Button Toggle
            Expanded(
              child: SizedBox(
                height: 40,
                child: ChoiceChip(
                  label: const Text('Cash Pay', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  selected: _paymentMode == 'Cash',
                  selectedColor: const Color(0xFFD4AF37).withOpacity(0.3),
                  checkmarkColor: const Color(0xFF8B2500),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _paymentMode = 'Cash';
                        _showUpiQr = false;
                      });
                      if (onCartUpdate != null) onCartUpdate();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 6),
            // UPI Button Toggle
            Expanded(
              child: SizedBox(
                height: 40,
                child: ChoiceChip(
                  label: const Text('UPI Scan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  selected: _paymentMode == 'UPI',
                  selectedColor: Colors.green.withOpacity(0.2),
                  checkmarkColor: Colors.green[800],
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _paymentMode = 'UPI';
                        _showUpiQr = true;
                      });
                      if (onCartUpdate != null) onCartUpdate();
                    }
                  },
                ),
              ),
            ),
          ],
        ),

        // Dynamic UPI QR Code scanner view
        if (_showUpiQr && _totalAmount > 0) ...[
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green, width: 1.5),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: QrImageView(
                      data: upiUrl,
                      version: QrVersions.auto,
                      size: 140.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('Customer scans to pay total', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],

        // Share Bill Button
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE05A10),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 2,
            ),
            onPressed: (_cartItems.isEmpty || _isSharing)
                ? null
                : () async {
                    if (scrollController != null) Navigator.pop(context); // Close bottom drawer first
                    await _shareBill();
                  },
            icon: _isSharing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Icon(Icons.share, size: 24),
            label: Text(
              _isSharing ? 'Generating Receipt...' : 'Save & Share Bill',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
