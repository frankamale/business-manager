import 'package:bac_pos/models/users.dart';
import 'package:bac_pos/models/service_point.dart';
import 'package:bac_pos/models/inventory_item.dart';
import 'package:bac_pos/models/sale_transaction.dart';
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
      version: 5,
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

    if (oldVersion < 5) {
      // Add sales_transactions table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sales_transactions (
          id TEXT PRIMARY KEY,
          purchaseordernumber TEXT,
          internalrefno INTEGER NOT NULL,
          issuedby TEXT NOT NULL,
          receiptnumber TEXT NOT NULL,
          receivedby TEXT,
          remarks TEXT NOT NULL,
          transactiondate INTEGER NOT NULL,
          costcentre TEXT,
          destinationbp TEXT NOT NULL,
          paymentmode TEXT NOT NULL,
          sourcefacility TEXT NOT NULL,
          genno TEXT NOT NULL,
          paymenttype TEXT NOT NULL,
          validtill INTEGER NOT NULL,
          currency TEXT NOT NULL,
          quantity REAL NOT NULL,
          unitquantity REAL NOT NULL,
          amount REAL NOT NULL,
          amountpaid REAL NOT NULL,
          balance REAL NOT NULL,
          sellingprice REAL NOT NULL,
          costprice REAL NOT NULL,
          sellingprice_original REAL NOT NULL,
          inventoryname TEXT NOT NULL,
          category TEXT NOT NULL,
          subcategory TEXT NOT NULL,
          gnrtd INTEGER NOT NULL,
          printed INTEGER NOT NULL,
          redeemed INTEGER NOT NULL,
          cancelled INTEGER NOT NULL,
          patron TEXT NOT NULL,
          department TEXT NOT NULL,
          packsize INTEGER NOT NULL,
          packaging TEXT NOT NULL,
          complimentaryid INTEGER NOT NULL,
          salesId TEXT NOT NULL
        )
      ''');

      // Create index on salesId for faster queries
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_salesId ON sales_transactions(salesId)
      ''');

      // Create index on receiptnumber for faster queries
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_receiptnumber ON sales_transactions(receiptnumber)
      ''');

      // Create index on transactiondate for faster queries
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_transactiondate ON sales_transactions(transactiondate)
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

    await db.execute('''
      CREATE TABLE sales_transactions (
        id TEXT PRIMARY KEY,
        purchaseordernumber TEXT,
        internalrefno INTEGER NOT NULL,
        issuedby TEXT NOT NULL,
        receiptnumber TEXT NOT NULL,
        receivedby TEXT,
        remarks TEXT NOT NULL,
        transactiondate INTEGER NOT NULL,
        costcentre TEXT,
        destinationbp TEXT NOT NULL,
        paymentmode TEXT NOT NULL,
        sourcefacility TEXT NOT NULL,
        genno TEXT NOT NULL,
        paymenttype TEXT NOT NULL,
        validtill INTEGER NOT NULL,
        currency TEXT NOT NULL,
        quantity REAL NOT NULL,
        unitquantity REAL NOT NULL,
        amount REAL NOT NULL,
        amountpaid REAL NOT NULL,
        balance REAL NOT NULL,
        sellingprice REAL NOT NULL,
        costprice REAL NOT NULL,
        sellingprice_original REAL NOT NULL,
        inventoryname TEXT NOT NULL,
        category TEXT NOT NULL,
        subcategory TEXT NOT NULL,
        gnrtd INTEGER NOT NULL,
        printed INTEGER NOT NULL,
        redeemed INTEGER NOT NULL,
        cancelled INTEGER NOT NULL,
        patron TEXT NOT NULL,
        department TEXT NOT NULL,
        packsize INTEGER NOT NULL,
        packaging TEXT NOT NULL,
        complimentaryid INTEGER NOT NULL,
        salesId TEXT NOT NULL
      )
    ''');

    // Create indexes for faster queries
    await db.execute('''
      CREATE INDEX idx_salesId ON sales_transactions(salesId)
    ''');

    await db.execute('''
      CREATE INDEX idx_receiptnumber ON sales_transactions(receiptnumber)
    ''');

    await db.execute('''
      CREATE INDEX idx_transactiondate ON sales_transactions(transactiondate)
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

  // SALES TRANSACTION METHODS

  // Insert a single sale transaction
  Future<int> insertSaleTransaction(SaleTransaction transaction) async {
    final db = await database;
    return await db!.insert(
      'sales_transactions',
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Insert multiple sale transactions
  Future<void> insertSaleTransactions(List<SaleTransaction> transactions) async {
    final db = await database;
    final batch = db!.batch();

    for (var transaction in transactions) {
      batch.insert(
        'sales_transactions',
        transaction.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print('✅ ${transactions.length} sale transactions inserted into database');
  }

  // Get all sale transactions
  Future<List<SaleTransaction>> getSaleTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db!.query(
      'sales_transactions',
      orderBy: 'transactiondate DESC',
    );

    return List.generate(maps.length, (i) {
      return SaleTransaction.fromMap(maps[i]);
    });
  }

  // Get sale transactions by salesId (items from same sale)
  Future<List<SaleTransaction>> getSaleTransactionsBySalesId(String salesId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db!.query(
      'sales_transactions',
      where: 'salesId = ?',
      whereArgs: [salesId],
    );

    return List.generate(maps.length, (i) {
      return SaleTransaction.fromMap(maps[i]);
    });
  }

  // Get grouped sales (one entry per sale/receipt)
  Future<List<Map<String, dynamic>>> getGroupedSales() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db!.rawQuery('''
      SELECT
        salesId,
        receiptnumber,
        transactiondate,
        genno as reference,
        remarks as notes,
        paymentmode,
        paymenttype,
        destinationbp as customer,
        COUNT(DISTINCT id) as numberOfItems,
        SUM(amount) as totalAmount,
        SUM(amountpaid) as totalPaid,
        SUM(balance) as totalBalance,
        MAX(printed) as printed,
        MAX(cancelled) as cancelled
      FROM sales_transactions
      GROUP BY salesId
      ORDER BY transactiondate DESC
    ''');

    return result;
  }

  // Get sales by date range
  Future<List<SaleTransaction>> getSaleTransactionsByDateRange(
    int startDate,
    int endDate,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db!.query(
      'sales_transactions',
      where: 'transactiondate BETWEEN ? AND ?',
      whereArgs: [startDate, endDate],
      orderBy: 'transactiondate DESC',
    );

    return List.generate(maps.length, (i) {
      return SaleTransaction.fromMap(maps[i]);
    });
  }

  // Get daily summary statistics
  Future<Map<String, dynamic>> getDailySummary(int date) async {
    final db = await database;

    // Start and end of day in milliseconds
    final startOfDay = DateTime.fromMillisecondsSinceEpoch(date);
    final startMillis = DateTime(startOfDay.year, startOfDay.month, startOfDay.day).millisecondsSinceEpoch;
    final endMillis = DateTime(startOfDay.year, startOfDay.month, startOfDay.day, 23, 59, 59).millisecondsSinceEpoch;

    // Get payment method totals
    final paymentSummary = await db!.rawQuery('''
      SELECT
        paymenttype,
        SUM(amountpaid) as totalPaid
      FROM sales_transactions
      WHERE transactiondate BETWEEN ? AND ?
      GROUP BY paymenttype
    ''', [startMillis, endMillis]);

    // Get category totals
    final categorySummary = await db.rawQuery('''
      SELECT
        category,
        SUM(amount) as totalAmount
      FROM sales_transactions
      WHERE transactiondate BETWEEN ? AND ?
      GROUP BY category
    ''', [startMillis, endMillis]);

    // Get complementary items total
    final complementaryTotal = await db.rawQuery('''
      SELECT
        SUM(amount) as total
      FROM sales_transactions
      WHERE transactiondate BETWEEN ? AND ? AND complimentaryid > 0
    ''', [startMillis, endMillis]);

    // Get overall totals
    final overallTotal = await db.rawQuery('''
      SELECT
        SUM(amount) as totalSales,
        SUM(amountpaid) as totalPaid,
        SUM(balance) as totalBalance,
        COUNT(DISTINCT salesId) as totalTransactions
      FROM sales_transactions
      WHERE transactiondate BETWEEN ? AND ?
    ''', [startMillis, endMillis]);

    return {
      'paymentSummary': paymentSummary,
      'categorySummary': categorySummary,
      'complementaryTotal': complementaryTotal.isNotEmpty ? complementaryTotal[0]['total'] ?? 0.0 : 0.0,
      'overallTotal': overallTotal.isNotEmpty ? overallTotal[0] : {},
    };
  }

  // Delete all sale transactions
  Future<void> deleteAllSaleTransactions() async {
    final db = await database;
    await db!.delete('sales_transactions');
    print('All sale transactions deleted from database');
  }

  // Get sales count
  Future<int> getSalesCount() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db!.rawQuery('SELECT COUNT(DISTINCT salesId) FROM sales_transactions'),
    );
    return count ?? 0;
  }
}
