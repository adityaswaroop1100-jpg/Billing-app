import 'package:flutter/material.dart';
import '../models/item.dart';
import '../services/db_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _dbHelper = DatabaseHelper.instance;

  final _shopNameController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final _upiIdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<Item> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettingsAndItems();
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _shopAddressController.dispose();
    _upiIdController.dispose();
    super.dispose();
  }

  Future<void> _loadSettingsAndItems() async {
    setState(() => _isLoading = true);
    final name = await _dbHelper.getSetting('shop_name', 'Kaveri Sweets');
    final address = await _dbHelper.getSetting('shop_address', 'SR Dalmai Road, Madhupur, Deoghar');
    final upi = await _dbHelper.getSetting('upi_id', 'kaverisweets@upi');
    final items = await _dbHelper.getItems();

    _shopNameController.text = name;
    _shopAddressController.text = address;
    _upiIdController.text = upi;

    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  Future<void> _saveShopDetails() async {
    if (_formKey.currentState!.validate()) {
      await _dbHelper.updateSetting('shop_name', _shopNameController.text.trim());
      await _dbHelper.updateSetting('shop_address', _shopAddressController.text.trim());
      await _dbHelper.updateSetting('upi_id', _upiIdController.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shop details saved successfully!'),
            backgroundColor: Color(0xFFE05A10),
          ),
        );
      }
    }
  }

  void _showAddEditItemDialog([Item? item]) {
    final nameController = TextEditingController(text: item?.name ?? '');
    final priceController = TextEditingController(text: item?.price != null ? item!.price.toStringAsFixed(1) : '');
    String priceType = item?.priceType ?? 'weight'; // Default is weight (₹/kg)
    final dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFFFFDF9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                item == null ? 'Add New Sweet' : 'Edit Sweet',
                style: const TextStyle(color: Color(0xFF8B2500), fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: dialogFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sweet Name
                      TextFormField(
                        controller: nameController,
                        style: const TextStyle(fontSize: 16),
                        decoration: const InputDecoration(
                          labelText: 'Sweet Name (e.g. Laddu)',
                          labelStyle: TextStyle(color: Color(0xFF8B2500)),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFE05A10)),
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty ? 'Please enter sweet name' : null,
                      ),
                      const SizedBox(height: 16),

                      // Price Type (Weight vs Piece)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sold By:',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF5A4A42)),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: RadioListTile<String>(
                                  title: const Text('Weight (₹/kg)', style: TextStyle(fontSize: 14)),
                                  value: 'weight',
                                  groupValue: priceType,
                                  activeColor: const Color(0xFFE05A10),
                                  onChanged: (val) {
                                    if (val != null) setDialogState(() => priceType = val);
                                  },
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<String>(
                                  title: const Text('Piece (₹/unit)', style: TextStyle(fontSize: 14)),
                                  value: 'piece',
                                  groupValue: priceType,
                                  activeColor: const Color(0xFFE05A10),
                                  onChanged: (val) {
                                    if (val != null) setDialogState(() => priceType = val);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Price
                      TextFormField(
                        controller: priceController,
                        style: const TextStyle(fontSize: 16),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: priceType == 'weight' ? 'Price per kg (₹)' : 'Price per piece (₹)',
                          labelStyle: const TextStyle(color: Color(0xFF8B2500)),
                          prefixText: '₹ ',
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFE05A10)),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter price';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: () async {
                    if (dialogFormKey.currentState!.validate()) {
                      final name = nameController.text.trim();
                      final price = double.parse(priceController.text.trim());

                      final newItem = Item(
                        id: item?.id,
                        name: name,
                        priceType: priceType,
                        price: price,
                      );

                      await _dbHelper.insertItem(newItem);
                      Navigator.pop(context);
                      _loadSettingsAndItems();
                    }
                  },
                  child: Text(item == null ? 'Add' : 'Save', style: const TextStyle(fontSize: 16)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteItem(Item item) async {
    if (item.id == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDF9),
        title: const Text('Delete Item', style: TextStyle(color: Color(0xFF8B2500), fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete ${item.name}? This will remove it from the billing screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbHelper.deleteItem(item.id!);
      _loadSettingsAndItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      appBar: AppBar(
        title: const Text(
          'Shop Settings & Inventory',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFE05A10),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFFE05A10))))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SHOP CONFIGURATION CARD ---
                  Card(
                    color: const Color(0xFFFFFDF9),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFD4AF37), width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.store, color: Color(0xFFE05A10)),
                                SizedBox(width: 8),
                                Text(
                                  'Shop Details',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF8B2500),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20, color: Color(0xFFE05A10)),
                            
                            // Shop Name
                            TextFormField(
                              controller: _shopNameController,
                              style: const TextStyle(fontSize: 16),
                              decoration: const InputDecoration(
                                labelText: 'Shop Name',
                                labelStyle: TextStyle(color: Color(0xFF8B2500)),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFFE05A10)),
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty ? 'Please enter shop name' : null,
                            ),
                            const SizedBox(height: 12),

                            // Shop Address
                            TextFormField(
                              controller: _shopAddressController,
                              style: const TextStyle(fontSize: 16),
                              decoration: const InputDecoration(
                                labelText: 'Shop Address',
                                labelStyle: TextStyle(color: Color(0xFF8B2500)),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFFE05A10)),
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty ? 'Please enter shop address' : null,
                            ),
                            const SizedBox(height: 12),

                            // UPI ID
                            TextFormField(
                              controller: _upiIdController,
                              style: const TextStyle(fontSize: 16),
                              decoration: const InputDecoration(
                                labelText: 'Owner UPI ID (for QR payment)',
                                labelStyle: TextStyle(color: Color(0xFF8B2500)),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFFE05A10)),
                                ),
                                helperText: 'Example: kaverisweets@upi or 9876543210@paytm',
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty ? 'Please enter UPI ID' : null,
                            ),
                            const SizedBox(height: 16),

                            // Save Details Button
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE05A10),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: _saveShopDetails,
                                child: const Text('Save Shop Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- INVENTORY MANAGEMENT SECTION ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Sweet Catalog',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B2500),
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B2500),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onPressed: () => _showAddEditItemDialog(),
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text('Add Sweet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _items.isEmpty
                      ? const Card(
                          color: Color(0xFFFFFDF9),
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Center(
                              child: Text(
                                'No sweets added yet. Click Add Sweet above.',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return Card(
                              color: const Color(0xFFFFFDF9),
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                title: Text(
                                  item.name,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4A2711)),
                                ),
                                subtitle: Text(
                                  item.priceType == 'weight' ? '₹ ${item.price}/kg' : '₹ ${item.price}/piece',
                                  style: const TextStyle(fontSize: 14, color: Color(0xFFE05A10), fontWeight: FontWeight.w600),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blueGrey, size: 28),
                                      onPressed: () => _showAddEditItemDialog(item),
                                      tooltip: 'Edit Sweet',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red, size: 28),
                                      onPressed: () => _deleteItem(item),
                                      tooltip: 'Delete Sweet',
                                    ),
                                  ],
                                ),
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
