import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/item.dart';
import '../models/bill.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('kaveri_sweets.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Create items table
    await db.execute('''
      CREATE TABLE items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        price_type TEXT NOT NULL,
        price REAL NOT NULL
      )
    ''');

    // 2. Create bills table
    await db.execute('''
      CREATE TABLE bills(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        items_json TEXT NOT NULL,
        subtotal REAL NOT NULL DEFAULT 0.0,
        discount REAL NOT NULL DEFAULT 0.0,
        total_amount REAL NOT NULL,
        payment_mode TEXT NOT NULL,
        date_time TEXT NOT NULL
      )
    ''');

    // 3. Create settings table
    await db.execute('''
      CREATE TABLE settings(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Insert default settings
    await db.insert('settings', {'key': 'upi_id', 'value': 'kaverisweets@upi'});
    await db.insert('settings', {'key': 'shop_name', 'value': 'Kaveri Sweets'});
    await db.insert('settings', {
      'key': 'shop_address',
      'value': 'SR Dalmai Road, Madhupur, Deoghar'
    });

    // Insert default sweets
    final defaultItems = [
      Item(name: 'Kaju Katli', priceType: 'weight', price: 800.0),
      Item(name: 'Rasgulla', priceType: 'piece', price: 15.0),
      Item(name: 'Gulab Jamun', priceType: 'piece', price: 15.0),
      Item(name: 'Motichoor Laddoo', priceType: 'weight', price: 360.0),
      Item(name: 'Kesar Peda', priceType: 'weight', price: 600.0),
      Item(name: 'Milk Cake', priceType: 'weight', price: 650.0),
      Item(name: 'Besan Laddoo', priceType: 'weight', price: 400.0),
      Item(name: 'Rasmalai', priceType: 'piece', price: 30.0),
      Item(name: 'Samosa', priceType: 'piece', price: 12.0),
      Item(name: 'Jalebi', priceType: 'weight', price: 200.0),
      Item(name: 'Dhokla', priceType: 'weight', price: 240.0),
      Item(name: 'Assorted Sweets Box', priceType: 'weight', price: 550.0),
    ];

    for (var item in defaultItems) {
      await db.insert('items', item.toMap());
    }
  }

  // --- ITEM CRUD OPERATIONS ---

  Future<int> insertItem(Item item) async {
    final db = await instance.database;
    return await db.insert('items', item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Item>> getItems() async {
    final db = await instance.database;
    final maps = await db.query('items', orderBy: 'name ASC');
    return maps.map((map) => Item.fromMap(map)).toList();
  }

  Future<int> updateItem(Item item) async {
    final db = await instance.database;
    return await db.update(
      'items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteItem(int id) async {
    final db = await instance.database;
    return await db.delete(
      'items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- BILL CRUD OPERATIONS ---

  Future<int> insertBill(Bill bill) async {
    final db = await instance.database;
    return await db.insert('bills', bill.toMap());
  }

  Future<List<Bill>> getBills() async {
    final db = await instance.database;
    final maps = await db.query('bills', orderBy: 'date_time DESC');
    return maps.map((map) => Bill.fromMap(map)).toList();
  }

  Future<List<Bill>> getBillsByDate(DateTime date) async {
    final db = await instance.database;
    final startOfDay = DateTime(date.year, date.month, date.day).toIso8601String();
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();

    final maps = await db.query(
      'bills',
      where: 'date_time >= ? AND date_time <= ?',
      whereArgs: [startOfDay, endOfDay],
      orderBy: 'date_time DESC',
    );
    return maps.map((map) => Bill.fromMap(map)).toList();
  }

  // --- SETTINGS OPERATIONS ---

  Future<String> getSetting(String key, String defaultValue) async {
    final db = await instance.database;
    final maps = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) {
      return maps.first['value'] as String;
    }
    return defaultValue;
  }

  Future<void> updateSetting(String key, String value) async {
    final db = await instance.database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Close connection
  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
