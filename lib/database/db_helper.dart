import 'package:bac_pos/models/users.dart';
import 'package:bac_pos/models/service_point.dart';
import 'package:bac_pos/models/inventory_item.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database?> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), "my_database.db");
    return await openDatabase(
      path,
      version: 4,  // Incremented version to add inventory table
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Drop old table and recreate with correct schema
      await db.execute('DROP TABLE IF EXISTS user');
      await _onCreate(db, newVersion);
    }

    if (oldVersion < 3) {
      // Add service_point table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS service_point (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          code TEXT NOT NULL,
          fullName TEXT NOT NULL,
          servicepointtype TEXT NOT NULL,
          facilityName TEXT NOT NULL,
          sales INTEGER NOT NULL,
          stores INTEGER NOT NULL,
          production INTEGER NOT NULL,
          booking INTEGER NOT NULL
        )
      ''');
    }

    if (oldVersion < 4) {
      // Add inventory table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS inventory (
          id TEXT PRIMARY KEY,
          ipdid TEXT NOT NULL,
          code TEXT NOT NULL,
          externalserial TEXT NOT NULL,
          name TEXT NOT NULL,
          category TEXT NOT NULL,
          price REAL NOT NULL,
          costprice REAL,
          packsize REAL NOT NULL,
          packaging TEXT NOT NULL,
          packagingid TEXT NOT NULL,
          soldfrom TEXT NOT NULL,
          shortform TEXT NOT NULL,
          packagingcode TEXT NOT NULL,
          efris INTEGER NOT NULL,
          efrisid TEXT NOT NULL,
          measurmentunitidefris TEXT NOT NULL,
          measurmentunit TEXT NOT NULL,
          measurmentunitid TEXT NOT NULL,
          vatcategoryid TEXT NOT NULL,
          branchid TEXT NOT NULL,
          companyid TEXT NOT NULL,
          downloadlink TEXT
        )
      ''');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE user (
      id TEXT PRIMARY KEY,
      name TEXT,
      branch TEXT,
      company TEXT,
      role TEXT,
      branchname TEXT,
      companyName TEXT,
      username TEXT,
      staff TEXT,
      staffid TEXT,
      salespersonid TEXT,
      companyid TEXT,
      pospassword INTEGER
      )
      ''');

    await db.execute('''
      CREATE TABLE service_point (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        code TEXT NOT NULL,
        fullName TEXT NOT NULL,
        servicepointtype TEXT NOT NULL,
        facilityName TEXT NOT NULL,
        sales INTEGER NOT NULL,
        stores INTEGER NOT NULL,
        production INTEGER NOT NULL,
        booking INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE inventory (
        id TEXT PRIMARY KEY,
        ipdid TEXT NOT NULL,
        code TEXT NOT NULL,
        externalserial TEXT NOT NULL,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        price REAL NOT NULL,
        costprice REAL,
        packsize REAL NOT NULL,
        packaging TEXT NOT NULL,
        packagingid TEXT NOT NULL,
        soldfrom TEXT NOT NULL,
        shortform TEXT NOT NULL,
        packagingcode TEXT NOT NULL,
        efris INTEGER NOT NULL,
        efrisid TEXT NOT NULL,
        measurmentunitidefris TEXT NOT NULL,
        measurmentunit TEXT NOT NULL,
        measurmentunitid TEXT NOT NULL,
        vatcategoryid TEXT NOT NULL,
        branchid TEXT NOT NULL,
        companyid TEXT NOT NULL,
        downloadlink TEXT
      )
    ''');
  }

  Future<int> insertUser(User user) async {
    final db = await database;
    return await db!.insert(
      'user',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<User>> get users async {
    Database? db = await database;
    final List<Map<String, dynamic>> maps = await db!.query('user');
    return List.generate(maps.length, (i) {
      return User.fromMap(maps[i]);
    });
  }

  // Insert multiple users
  Future<void> insertUsers(List<User> users) async {
    final db = await database;
    final batch = db!.batch();

    for (var user in users) {
      batch.insert(
        'user',
        user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  // Get unique roles from users
  Future<List<String>> getUniqueRoles() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db!.query(
      'user',
      columns: ['role'],
      distinct: true,
      orderBy: 'role ASC',
    );

    return result.map((map) => map['role'] as String).toList();
  }

  // Get all usernames for login display (only users with salespersonid)
  Future<List<String>> getAllRoles() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db!.query(
      'user',
      columns: ['username'],
      where: 'salespersonid IS NOT NULL AND salespersonid != ?',
      whereArgs: [''],
      orderBy: 'username ASC',
    );

    return result.map((map) => map['username'] as String).toList();
  }

  // Get users by role
  Future<List<User>> getUsersByRole(String role) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db!.query(
      'user',
      where: 'role = ?',
      whereArgs: [role],
    );

    return List.generate(maps.length, (i) {
      return User.fromMap(maps[i]);
    });
  }

  // Get users with salespersonid (not null or empty)
  Future<List<User>> getUsersWithSalespersonId() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db!.query(
      'user',
      where: 'salespersonid IS NOT NULL AND salespersonid != ?',
      whereArgs: [''],
    );

    return List.generate(maps.length, (i) {
      return User.fromMap(maps[i]);
    });
  }

  // Authenticate user by role and password
  Future<User?> authenticateUser(String role, int password) async {
    try {
      final db = await database;
      print('Authenticating user with role: $role and password: $password');

      final List<Map<String, dynamic>> maps = await db!.query(
        'user',
        where: 'role = ? AND pospassword = ?',
        whereArgs: [role, password],
        limit: 1,
      );

      if (maps.isEmpty) {
        print('No user found with role: $role and the provided password');
        return null;
      }

      final user = User.fromMap(maps.first);
      print('Authentication successful for user: ${user.name} (${user.username})');
      return user;
    } catch (e) {
      print('Error during authentication: $e');
      return null;
    }
  }

  // Authenticate user by username and password
  Future<User?> authenticateUserByUsername(String username, int password) async {
    try {
      final db = await database;
      print('Authenticating user with username: $username and password: $password');

      final List<Map<String, dynamic>> maps = await db!.query(
        'user',
        where: 'username = ? AND pospassword = ?',
        whereArgs: [username, password],
        limit: 1,
      );

      if (maps.isEmpty) {
        print('No user found with username: $username and the provided password');
        return null;
      }

      final user = User.fromMap(maps.first);
      print('Authentication successful for user: ${user.name} (${user.username})');
      return user;
    } catch (e) {
      print('Error during authentication: $e');
      return null;
    }
  }

  // Delete all users (useful for re-syncing)
  Future<void> deleteAllUsers() async {
    final db = await database;
    await db!.delete('user');
    print('All users deleted from database');
  }

  // SERVICE POINT METHODS

  // Insert a service point
  Future<int> insertServicePoint(ServicePoint servicePoint) async {
    final db = await database;
    return await db!.insert(
      'service_point',
      servicePoint.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Insert multiple service points
  Future<void> insertServicePoints(List<ServicePoint> servicePoints) async {
    final db = await database;
    final batch = db!.batch();

    for (var servicePoint in servicePoints) {
      batch.insert(
        'service_point',
        servicePoint.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  // Get all service points
  Future<List<ServicePoint>> getServicePoints() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db!.query('service_point');

    return List.generate(maps.length, (i) {
      return ServicePoint.fromMap(maps[i]);
    });
  }

  // Get service points with sales enabled
  Future<List<ServicePoint>> getSalesServicePoints() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db!.query(
      'service_point',
      where: 'sales = ?',
      whereArgs: [1],
    );

    return List.generate(maps.length, (i) {
      return ServicePoint.fromMap(maps[i]);
    });
  }

  // Delete all service points
  Future<void> deleteAllServicePoints() async {
    final db = await database;
    await db!.delete('service_point');
    print('All service points deleted from database');
  }

  // INVENTORY METHODS

  // Insert a single inventory item
  Future<int> insertInventoryItem(InventoryItem item) async {
    final db = await database;
    return await db!.insert(
      'inventory',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Insert multiple inventory items
  Future<void> insertInventoryItems(List<InventoryItem> items) async {
    final db = await database;
    final batch = db!.batch();

    for (var item in items) {
      batch.insert(
        'inventory',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print('✅ ${items.length} inventory items inserted into database');
  }

  // Get all inventory items
  Future<List<InventoryItem>> getInventoryItems() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db!.query('inventory');

    return List.generate(maps.length, (i) {
      return InventoryItem.fromMap(maps[i]);
    });
  }

  // Search inventory items by name, code, or category
  Future<List<InventoryItem>> searchInventoryItems(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db!.query(
      'inventory',
      where: 'name LIKE ? OR code LIKE ? OR category LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'name ASC',
    );

    return List.generate(maps.length, (i) {
      return InventoryItem.fromMap(maps[i]);
    });
  }

  // Get inventory items by category
  Future<List<InventoryItem>> getInventoryItemsByCategory(String category) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db!.query(
      'inventory',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'name ASC',
    );

    return List.generate(maps.length, (i) {
      return InventoryItem.fromMap(maps[i]);
    });
  }

  // Get unique categories
  Future<List<String>> getInventoryCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db!.query(
      'inventory',
      columns: ['category'],
      distinct: true,
      orderBy: 'category ASC',
    );

    return result.map((map) => map['category'] as String).toList();
  }

  // Delete all inventory items
  Future<void> deleteAllInventoryItems() async {
    final db = await database;
    await db!.delete('inventory');
    print('All inventory items deleted from database');
  }

  // Get inventory count
  Future<int> getInventoryCount() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db!.rawQuery('SELECT COUNT(*) FROM inventory'),
    );
    return count ?? 0;
  }
}
