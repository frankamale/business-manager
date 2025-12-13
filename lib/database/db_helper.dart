import 'package:bac_pos/models/users.dart';
import 'package:bac_pos/models/service_point.dart';
import 'package:bac_pos/models/inventory_item.dart';
import 'package:bac_pos/models/sale_transaction.dart';
import 'package:bac_pos/models/customer.dart';
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
      version: 10,
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
          receiptnumber TEXT,
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

    if (oldVersion < 6) {
      // Add sync_metadata table for tracking sync status
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_metadata (
          data_type TEXT PRIMARY KEY,
          last_sync_timestamp INTEGER NOT NULL,
          sync_status TEXT NOT NULL,
          record_count INTEGER DEFAULT 0,
          error_message TEXT
        )
      ''');

      // Add customers table for caching customer data
      await db.execute('''
        CREATE TABLE IF NOT EXISTS customers (
          id TEXT PRIMARY KEY,
          code TEXT,
          firstname TEXT,
          lastname TEXT,
          othernames TEXT,
          remarks TEXT,
          status TEXT,
          gender TEXT,
          fullnames TEXT NOT NULL,
          dob TEXT,
          category TEXT,
          designation TEXT,
          trackerid1 TEXT,
          trackerid2 TEXT,
          trackerid3 TEXT,
          trackerid4 TEXT,
          trackerid5 TEXT,
          trackerid6 TEXT,
          tracker1 TEXT,
          tracker2 TEXT,
          tracker3 TEXT,
          tracker4 TEXT,
          tracker5 TEXT,
          tracker6 TEXT,
          email TEXT,
          phone1 TEXT,
          address TEXT,
          title TEXT,
          guarantors TEXT,
          pospassword TEXT,
          posenabled INTEGER,
          posusername TEXT,
          pospasswordexpiry TEXT,
          statusid TEXT,
          subscription INTEGER,
          logo TEXT,
          mode INTEGER
        )
      ''');

      // Create indexes on customers table for faster queries
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_customer_fullnames ON customers(fullnames)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_customer_phone ON customers(phone1)
      ''');
    }

    if (oldVersion < 7) {
      // Allow receiptnumber to be NULL in sales_transactions table
      await db.execute('ALTER TABLE sales_transactions ALTER COLUMN receiptnumber TEXT;');
    }

    if (oldVersion < 8) {
      // Add upload tracking columns to sales_transactions table
      await db.execute('ALTER TABLE sales_transactions ADD COLUMN upload_status TEXT DEFAULT "pending"');
      await db.execute('ALTER TABLE sales_transactions ADD COLUMN uploaded_at INTEGER');
      await db.execute('ALTER TABLE sales_transactions ADD COLUMN upload_error TEXT');
    }

    if (oldVersion < 9) {
      // Add inventory tracking columns to sales_transactions table
      await db.execute('ALTER TABLE sales_transactions ADD COLUMN inventoryid TEXT');
      await db.execute('ALTER TABLE sales_transactions ADD COLUMN ipdid TEXT');
    }

    if (oldVersion < 10) {
      // Add full ID columns for proper payload reconstruction
      await db.execute('ALTER TABLE sales_transactions ADD COLUMN clientid TEXT');
      await db.execute('ALTER TABLE sales_transactions ADD COLUMN companyid TEXT');
      await db.execute('ALTER TABLE sales_transactions ADD COLUMN branchid TEXT');
      await db.execute('ALTER TABLE sales_transactions ADD COLUMN servicepointid TEXT');
      await db.execute('ALTER TABLE sales_transactions ADD COLUMN salespersonid TEXT');
    }

    if (oldVersion < 11) {
      // Add server_sales table for storing fetched sales data from server
      await db.execute('''
        CREATE TABLE IF NOT EXISTS server_sales (
          id TEXT PRIMARY KEY,
          transactiontypeid INTEGER NOT NULL,
          patrontype TEXT,
          purchaseorderno TEXT,
          internalrefno INTEGER NOT NULL,
          issuedby TEXT,
          receiptnumber TEXT,
          receivedby TEXT,
          remarks TEXT NOT NULL,
          transactiondate INTEGER NOT NULL,
          entrytimestamp INTEGER NOT NULL,
          destinationbp TEXT NOT NULL,
          paymentmode TEXT NOT NULL,
          sellingpoint TEXT NOT NULL,
          genno TEXT NOT NULL,
          paymentterms TEXT NOT NULL,
          validtill INTEGER NOT NULL,
          currency TEXT NOT NULL,
          quantity REAL NOT NULL,
          unitquantity REAL NOT NULL,
          amount REAL NOT NULL,
          costamount REAL NOT NULL,
          amountpaid REAL NOT NULL,
          balance REAL NOT NULL,
          cnt INTEGER NOT NULL,
          inventoryname TEXT,
          category TEXT,
          subcategory TEXT,
          salesperson TEXT NOT NULL,
          locationid TEXT NOT NULL,
          location TEXT NOT NULL,
          tillid TEXT NOT NULL,
          till TEXT NOT NULL,
          service INTEGER NOT NULL,
          payments INTEGER NOT NULL,
          committed INTEGER NOT NULL,
          ready INTEGER NOT NULL,
          transactionstatus TEXT NOT NULL,
          products REAL NOT NULL,
          services REAL NOT NULL,
          reportingcurrencyrate REAL NOT NULL,
          efris INTEGER NOT NULL,
          efrisstatus INTEGER NOT NULL,
          efrismessage TEXT,
          salesId TEXT NOT NULL,
          stageid TEXT,
          returnid TEXT
        )
      ''');

      // Create index on salesId for faster queries
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_server_sales_salesId ON server_sales(salesId)
      ''');

      // Create index on transactiondate for faster queries
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_server_sales_transactiondate ON server_sales(transactiondate)
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
        receiptnumber TEXT,
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
        salesId TEXT NOT NULL,
        upload_status TEXT DEFAULT 'pending',
        uploaded_at INTEGER,
        upload_error TEXT,
        inventoryid TEXT,
        ipdid TEXT,
        clientid TEXT,
        companyid TEXT,
        branchid TEXT,
        servicepointid TEXT,
        salespersonid TEXT
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

    // Create sync_metadata table for tracking sync status
    await db.execute('''
      CREATE TABLE sync_metadata (
        data_type TEXT PRIMARY KEY,
        last_sync_timestamp INTEGER NOT NULL,
        sync_status TEXT NOT NULL,
        record_count INTEGER DEFAULT 0,
        error_message TEXT
      )
    ''');

    // Create customers table for caching customer data
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        code TEXT,
        firstname TEXT,
        lastname TEXT,
        othernames TEXT,
        remarks TEXT,
        status TEXT,
        gender TEXT,
        fullnames TEXT NOT NULL,
        dob TEXT,
        category TEXT,
        designation TEXT,
        trackerid1 TEXT,
        trackerid2 TEXT,
        trackerid3 TEXT,
        trackerid4 TEXT,
        trackerid5 TEXT,
        trackerid6 TEXT,
        tracker1 TEXT,
        tracker2 TEXT,
        tracker3 TEXT,
        tracker4 TEXT,
        tracker5 TEXT,
        tracker6 TEXT,
        email TEXT,
        phone1 TEXT,
        address TEXT,
        title TEXT,
        guarantors TEXT,
        pospassword TEXT,
        posenabled INTEGER,
        posusername TEXT,
        pospasswordexpiry TEXT,
        statusid TEXT,
        subscription INTEGER,
        logo TEXT,
        mode INTEGER
      )
    ''');

    // Create indexes on customers table
    await db.execute('''
      CREATE INDEX idx_customer_fullnames ON customers(fullnames)
    ''');

    await db.execute('''
      CREATE INDEX idx_customer_phone ON customers(phone1)
    ''');

    // Create server_sales table for storing fetched sales data from server
    await db.execute('''
      CREATE TABLE server_sales (
        id TEXT PRIMARY KEY,
        transactiontypeid INTEGER NOT NULL,
        patrontype TEXT,
        purchaseorderno TEXT,
        internalrefno INTEGER NOT NULL,
        issuedby TEXT,
        receiptnumber TEXT,
        receivedby TEXT,
        remarks TEXT NOT NULL,
        transactiondate INTEGER NOT NULL,
        entrytimestamp INTEGER NOT NULL,
        destinationbp TEXT NOT NULL,
        paymentmode TEXT NOT NULL,
        sellingpoint TEXT NOT NULL,
        genno TEXT NOT NULL,
        paymentterms TEXT NOT NULL,
        validtill INTEGER NOT NULL,
        currency TEXT NOT NULL,
        quantity REAL NOT NULL,
        unitquantity REAL NOT NULL,
        amount REAL NOT NULL,
        costamount REAL NOT NULL,
        amountpaid REAL NOT NULL,
        balance REAL NOT NULL,
        cnt INTEGER NOT NULL,
        inventoryname TEXT,
        category TEXT,
        subcategory TEXT,
        salesperson TEXT NOT NULL,
        locationid TEXT NOT NULL,
        location TEXT NOT NULL,
        tillid TEXT NOT NULL,
        till TEXT NOT NULL,
        service INTEGER NOT NULL,
        payments INTEGER NOT NULL,
        committed INTEGER NOT NULL,
        ready INTEGER NOT NULL,
        transactionstatus TEXT NOT NULL,
        products REAL NOT NULL,
        services REAL NOT NULL,
        reportingcurrencyrate REAL NOT NULL,
        efris INTEGER NOT NULL,
        efrisstatus INTEGER NOT NULL,
        efrismessage TEXT,
        salesId TEXT NOT NULL,
        stageid TEXT,
        returnid TEXT
      )
    ''');

    // Create indexes for server_sales table
    await db.execute('''
      CREATE INDEX idx_server_sales_salesId ON server_sales(salesId)
    ''');

    await db.execute('''
      CREATE INDEX idx_server_sales_transactiondate ON server_sales(transactiondate)
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

  // Get inventory items by soldfrom (service point type)
  Future<List<InventoryItem>> getInventoryItemsBySoldFrom(String soldFrom) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db!.query(
      'inventory',
      where: 'soldfrom = ?',
      whereArgs: [soldFrom],
      orderBy: 'name ASC',
    );

    return List.generate(maps.length, (i) {
      return InventoryItem.fromMap(maps[i]);
    });
  }

  // Delete all inventory items
  Future<void> deleteAllInventoryItems() async {
    final db = await database;
    await db!.delete('inventory');
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
        MAX(cancelled) as cancelled,
        upload_status,
        uploaded_at,
        upload_error
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

    // Get overall totals with proper categorization
    final overallTotal = await db.rawQuery('''
      SELECT
        SUM(amount) as totalSales,
        SUM(amountpaid) as totalPaid,
        SUM(balance) as totalBalance,
        SUM(CASE WHEN balance = 0 AND amountpaid > 0 THEN amountpaid ELSE 0 END) as fullyPaidAmount,
        SUM(CASE WHEN balance > 0 AND amountpaid > 0 THEN amountpaid ELSE 0 END) as partialPaymentAmount,
        COUNT(DISTINCT salesId) as totalTransactions,
        COUNT(DISTINCT CASE WHEN balance = 0 AND amountpaid > 0 THEN salesId END) as fullyPaidTransactions,
        COUNT(DISTINCT CASE WHEN balance > 0 AND amountpaid > 0 THEN salesId END) as partialPaymentTransactions,
        COUNT(DISTINCT CASE WHEN balance > 0 THEN salesId END) as unpaidTransactions
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
  }

  // Get sales count
  Future<int> getSalesCount() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db!.rawQuery('SELECT COUNT(DISTINCT salesId) FROM sales_transactions'),
    );
    return count ?? 0;
  }

  // Update upload status for a sale (all transactions with same salesId)
  Future<void> updateSaleUploadStatus(
    String salesId,
    String status, {
    String? errorMessage,
  }) async {
    final db = await database;
    final updateData = {
      'upload_status': status,
      'uploaded_at': status == 'uploaded' ? DateTime.now().millisecondsSinceEpoch : null,
      'upload_error': errorMessage,
    };

    await db!.update(
      'sales_transactions',
      updateData,
      where: 'salesId = ?',
      whereArgs: [salesId],
    );
  }

  // Get sales by upload status
  Future<List<Map<String, dynamic>>> getSalesByUploadStatus(String status) async {
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
        MAX(cancelled) as cancelled,
        upload_status,
        uploaded_at,
        upload_error
      FROM sales_transactions
      WHERE upload_status = ?
      GROUP BY salesId
      ORDER BY transactiondate DESC
    ''', [status]);

    return result;
  }

  // SYNC METADATA METHODS

  // Update sync metadata after a sync operation
  Future<void> updateSyncMetadata(
    String dataType,
    String status,
    int recordCount, [
    String? errorMessage,
  ]) async {
    final db = await database;
    await db!.insert(
      'sync_metadata',
      {
        'data_type': dataType,
        'last_sync_timestamp': DateTime.now().millisecondsSinceEpoch,
        'sync_status': status,
        'record_count': recordCount,
        'error_message': errorMessage,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get sync metadata for a specific data type
  Future<Map<String, dynamic>?> getSyncMetadata(String dataType) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db!.query(
      'sync_metadata',
      where: 'data_type = ?',
      whereArgs: [dataType],
      limit: 1,
    );

    return result.isNotEmpty ? result.first : null;
  }

  // Check if cached data exists for a data type
  Future<bool> hasCachedData(String dataType) async {
    final db = await database;
    int count = 0;

    switch (dataType) {
      case 'users':
        count = Sqflite.firstIntValue(
          await db!.rawQuery('SELECT COUNT(*) FROM user'),
        ) ?? 0;
        break;
      case 'service_points':
        count = Sqflite.firstIntValue(
          await db!.rawQuery('SELECT COUNT(*) FROM service_point'),
        ) ?? 0;
        break;
      case 'inventory':
        count = await getInventoryCount();
        break;
      case 'sales_transactions':
        count = await getSalesCount();
        break;
      case 'customers':
        count = Sqflite.firstIntValue(
          await db!.rawQuery('SELECT COUNT(*) FROM customers'),
        ) ?? 0;
        break;
    }

    return count > 0;
  }

  // CUSTOMER METHODS

  // Insert a single customer
  Future<int> insertCustomer(Customer customer) async {
    final db = await database;
    return await db!.insert(
      'customers',
      customer.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Insert multiple customers
  Future<void> insertCustomers(List<Customer> customers) async {
    final db = await database;
    final batch = db!.batch();

    for (var customer in customers) {
      batch.insert(
        'customers',
        customer.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  // Get all customers
  Future<List<Customer>> getCustomers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db!.query(
      'customers',
      orderBy: 'fullnames ASC',
    );

    return List.generate(maps.length, (i) {
      return Customer.fromMap(maps[i]);
    });
  }

  // Search customers by fullnames or phone
  Future<List<Customer>> searchCustomers(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db!.query(
      'customers',
      where: 'fullnames LIKE ? OR phone1 LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'fullnames ASC',
    );

    return List.generate(maps.length, (i) {
      return Customer.fromMap(maps[i]);
    });
  }

  // Get customer by ID
  Future<Customer?> getCustomerById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db!.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    return maps.isNotEmpty ? Customer.fromMap(maps.first) : null;
  }

  // Delete all customers
  Future<void> deleteAllCustomers() async {
    final db = await database;
    await db!.delete('customers');
    print('All customers deleted from database');
  }

  // Get customer count
  Future<int> getCustomerCount() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db!.rawQuery('SELECT COUNT(*) FROM customers'),
    );
    return count ?? 0;
  }

  // SERVER SALES METHODS

  // Insert server sales data (replace existing data)
  Future<void> insertServerSales(List<Map<String, dynamic>> salesData) async {
    final db = await database;
    final batch = db!.batch();

    // Clear existing data first
    await db.delete('server_sales');

    // Insert new data
    for (var sale in salesData) {
      batch.insert(
        'server_sales',
        sale,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  // Get server sales by salesId
  Future<Map<String, dynamic>?> getServerSaleBySalesId(String salesId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db!.query(
      'server_sales',
      where: 'salesId = ?',
      whereArgs: [salesId],
      limit: 1,
    );

    return maps.isNotEmpty ? maps.first : null;
  }

  // Update local sales_transactions with server payment data
  Future<void> syncLocalSalesWithServerData() async {
    final db = await database;

    // Get all unique salesIds from local sales_transactions
    final localSalesIds = await db!.rawQuery('''
      SELECT DISTINCT salesId FROM sales_transactions
    ''');

    for (var row in localSalesIds) {
      final salesId = row['salesId'] as String;

      // Get server data for this salesId
      final serverSale = await getServerSaleBySalesId(salesId);

      if (serverSale != null) {
        final serverAmountPaid = (serverSale['amountpaid'] as num?)?.toDouble() ?? 0.0;
        final serverBalance = (serverSale['balance'] as num?)?.toDouble() ?? 0.0;
        final serverPaymentMode = serverSale['paymentmode'] as String? ?? 'Cash';

        // Check if this is a partial payment (balance > 0 and amountpaid > 0)
        final isPartialPayment = serverBalance > 0 && serverAmountPaid > 0;

        // Log partial payment sync
        if (isPartialPayment) {
          print('Syncing partial payment for salesId: $salesId, Amount Paid: $serverAmountPaid, Balance: $serverBalance');
        }

        // Update all transactions for this salesId
        await db.update(
          'sales_transactions',
          {
            'amountpaid': serverAmountPaid,
            'balance': serverBalance,
            'paymentmode': serverPaymentMode,
            'paymenttype': serverPaymentMode,
          },
          where: 'salesId = ?',
          whereArgs: [salesId],
        );

        print('Synced salesId: $salesId with server data - Amount Paid: $serverAmountPaid, Balance: $serverBalance');
      }
    }
  }

  // Get server sales count
  Future<int> getServerSalesCount() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db!.rawQuery('SELECT COUNT(*) FROM server_sales'),
    );
    return count ?? 0;
  }

  // Delete all server sales
  Future<void> deleteAllServerSales() async {
    final db = await database;
    await db!.delete('server_sales');
  }
}
