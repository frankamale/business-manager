import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../back_pos/models/users.dart';
import '../../back_pos/models/service_point.dart';
import '../../back_pos/models/inventory_item.dart';
import '../../back_pos/models/sale_transaction.dart';
import '../../back_pos/models/customer.dart';

/// Unified Database Helper that combines POS and Monitor databases
///
/// Tables from POS (unchanged):
/// - user, service_point, inventory, sales_transactions,
///   cash_accounts, customers, sync_metadata, server_sales
///
/// Tables from Monitor (prefixed with mon_):
/// - mon_service_points, company_details, mon_sales, mon_inventory
class UnifiedDatabaseHelper {
  static final UnifiedDatabaseHelper _instance = UnifiedDatabaseHelper._internal();

  static UnifiedDatabaseHelper get instance => _instance;

  factory UnifiedDatabaseHelper() => _instance;

  static Database? _database;
  static String? _currentCompanyId;
  static bool _isOpening = false;

  UnifiedDatabaseHelper._internal();

  /// Opens the database for a specific company
  /// If force is false and database is already open for this company, returns early
  Future<void> openForCompany(String companyId, {bool force = false}) async {
    // Prevent concurrent opening
    if (_isOpening) {
      print('DEBUG: UnifiedDatabaseHelper.openForCompany() - Already opening, waiting...');
      while (_isOpening) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      // After waiting, check if it's now open for the right company
      if (_currentCompanyId == companyId && _database != null) {
        print('DEBUG: UnifiedDatabaseHelper.openForCompany() - Database now open for $companyId after wait');
        return;
      }
    }

    // Skip if already open for same company (unless forced)
    if (!force && _currentCompanyId == companyId && _database != null) {
      print('DEBUG: UnifiedDatabaseHelper.openForCompany() - Already open for company $companyId, skipping');
      return;
    }

    _isOpening = true;
    try {
      print('DEBUG: UnifiedDatabaseHelper.openForCompany() - Opening database for company: $companyId');

      // Close existing database if open
      if (_database != null) {
        print('DEBUG: UnifiedDatabaseHelper.openForCompany() - Closing previous database for company: $_currentCompanyId');
        await _database!.close();
        _database = null;
        _currentCompanyId = null;
      }

      String path = join(
        await getDatabasesPath(),
        'unified_db_company_$companyId.db',
      );

      _database = await openDatabase(
        path,
        version: 1,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );

      _currentCompanyId = companyId;
      print('DEBUG: UnifiedDatabaseHelper.openForCompany() - Successfully opened database for company: $companyId');
    } finally {
      _isOpening = false;
    }
  }

  /// Synchronous getter for the database instance
  /// Throws an exception if no database is open
  Database get database {
    if (_database == null) {
      throw Exception('Database not opened. Call openForCompany first. Current companyId: $_currentCompanyId');
    }
    return _database!;
  }

  /// Async getter that auto-opens with default company if needed
  Future<Database> get databaseAsync async {
    if (_database == null) {
      print('WARNING: UnifiedDatabaseHelper.databaseAsync() - No database open, opening with default');
      await openForCompany('default');
    }
    return _database!;
  }

  /// Check if database is currently open
  bool get isDatabaseOpen => _database != null;

  /// Get current company ID
  String? get currentCompanyId => _currentCompanyId;

  /// Closes the current database
  Future<void> close() async {
    if (_database != null) {
      print('DEBUG: UnifiedDatabaseHelper.close() - Closing database for company: $_currentCompanyId');
      await _database!.close();
      _database = null;
      _currentCompanyId = null;
    }
  }

  /// Switch to a different company's database
  /// This is the preferred method for changing companies - it handles the check internally
  Future<void> switchCompany(String newCompanyId) async {
    print('DEBUG: UnifiedDatabaseHelper.switchCompany() - Switching to company: $newCompanyId (current: $_currentCompanyId)');
    if (_currentCompanyId == newCompanyId && _database != null) {
      print('DEBUG: UnifiedDatabaseHelper.switchCompany() - Already on company $newCompanyId, skipping');
      return;
    }
    await openForCompany(newCompanyId);
  }

  /// Ensure database is open for the given company
  /// Opens if not open, switches if open for different company
  Future<void> ensureOpenForCompany(String companyId) async {
    if (_database == null || _currentCompanyId != companyId) {
      await openForCompany(companyId);
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // ========== POS TABLES ==========

    // User table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user (
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

    // Service point table (POS)
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

    // Inventory table (POS)
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

    // Sales transactions table (POS)
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

    // Cash accounts table (POS)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cash_accounts (
        id TEXT PRIMARY KEY,
        accountname TEXT,
        accountnumber TEXT,
        reference TEXT,
        paymentmode_code TEXT,
        paymentmode_name TEXT,
        currency_id TEXT NOT NULL,
        currency_code TEXT NOT NULL,
        currency_name TEXT,
        main_currency INTEGER,
        branchid TEXT,
        companyid TEXT,
        pos INTEGER
      )
    ''');

    // Sync metadata table (POS)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_metadata (
        data_type TEXT PRIMARY KEY,
        last_sync_timestamp INTEGER NOT NULL,
        sync_status TEXT NOT NULL,
        record_count INTEGER DEFAULT 0,
        error_message TEXT
      )
    ''');

    // Customers table (POS)
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

    // Server sales table (POS)
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

    // ========== MONITOR TABLES (prefixed with mon_) ==========

    // Monitor service points table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mon_service_points (
        id TEXT PRIMARY KEY,
        name TEXT,
        code TEXT,
        branch TEXT,
        company TEXT,
        mainServicePoint INTEGER,
        stores INTEGER,
        sales INTEGER,
        production INTEGER,
        booking INTEGER,
        servicePointTypeId TEXT,
        departmentid TEXT,
        facilityName TEXT,
        facilityCode TEXT,
        fullName TEXT,
        servicepointtype TEXT
      )
    ''');

    // Company details table (Monitor)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS company_details (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch TEXT,
        company TEXT,
        userCode TEXT,
        currentBranchName TEXT,
        currentBranchCode TEXT,
        activeBranchName TEXT,
        activeBranchAddress TEXT,
        activeBranchPrimaryEmail TEXT,
        activeBranchCode TEXT,
        efrisEnabled INTEGER
      )
    ''');

    // Monitor sales table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mon_sales (
        id TEXT PRIMARY KEY,
        purchaseordernumber TEXT,
        internalrefno TEXT,
        issuedby TEXT,
        receiptnumber TEXT,
        receivedby TEXT,
        remarks TEXT,
        transactiondate INTEGER,
        costcentre TEXT,
        destinationbp TEXT,
        paymentmode TEXT,
        sourcefacility TEXT,
        genno TEXT,
        paymenttype TEXT,
        validtill INTEGER,
        currency TEXT,
        quantity REAL,
        unitquantity REAL,
        amount REAL,
        amountpaid REAL,
        balance REAL,
        sellingprice REAL,
        costprice REAL,
        sellingprice_original REAL,
        inventoryname TEXT,
        category TEXT,
        subcategory TEXT,
        gnrtd INTEGER,
        printed INTEGER,
        redeemed INTEGER,
        cancelled INTEGER,
        patron TEXT,
        department TEXT,
        packsize REAL,
        packaging TEXT,
        complimentaryid TEXT,
        salesId TEXT,
        service_point_id TEXT,
        salesperson TEXT
      )
    ''');

    // Monitor inventory table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mon_inventory (
        id TEXT PRIMARY KEY,
        ipdid TEXT,
        code TEXT,
        externalserial TEXT,
        name TEXT,
        category TEXT,
        price REAL,
        packsize REAL,
        packaging TEXT,
        packagingid TEXT,
        soldfrom TEXT,
        shortform TEXT,
        packagingcode TEXT,
        efris INTEGER,
        efrisid TEXT,
        measurmentunitidefris TEXT,
        measurmentunit TEXT,
        measurmentunitid TEXT,
        vatcategoryid TEXT,
        branchid TEXT,
        companyid TEXT,
        downloadlink TEXT
      )
    ''');

    // ========== INDEXES ==========

    // POS indexes
    await db.execute('CREATE INDEX IF NOT EXISTS idx_salesId ON sales_transactions(salesId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_receiptnumber ON sales_transactions(receiptnumber)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactiondate ON sales_transactions(transactiondate)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cash_accounts_currency ON cash_accounts(currency_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_customer_fullnames ON customers(fullnames)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_customer_phone ON customers(phone1)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_server_sales_salesId ON server_sales(salesId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_server_sales_transactiondate ON server_sales(transactiondate)');

    // Monitor indexes
    await db.execute('CREATE INDEX IF NOT EXISTS idx_mon_sales_transactiondate ON mon_sales(transactiondate)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_mon_sales_service_point ON mon_sales(service_point_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migrations will be handled here
  }

  // ========================================================================
  // POS USER METHODS
  // ========================================================================

  Future<int> insertUserModel(User user) async {
    final db = database;
    return await db.insert('user', user.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> insertUser(Map<String, dynamic> user) async {
    final db = database;
    return await db.insert('user', user, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<User>> get users async {
    final db = database;
    final maps = await db.query('user');
    return maps.map((map) => User.fromMap(map)).toList();
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    final db = database;
    return await db.query('user');
  }

  Future<void> insertUsers(List<User> users) async {
    final db = database;
    final batch = db.batch();
    for (var user in users) {
      batch.insert('user', user.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<String>> getUniqueRoles() async {
    final db = database;
    final result = await db.query('user', columns: ['role'], distinct: true, orderBy: 'role ASC');
    return result.map((map) => map['role'] as String).toList();
  }

  Future<List<String>> getAllRoles() async {
    final db = database;
    final result = await db.query(
      'user',
      columns: ['username'],
      where: 'salespersonid IS NOT NULL AND salespersonid != ?',
      whereArgs: [''],
      orderBy: 'username ASC',
    );
    return result.map((map) => map['username'] as String).toList();
  }

  Future<List<String>> getAllUsernames() async {
    final db = database;
    final result = await db.query(
      'user',
      columns: ['username'],
      where: 'salespersonid IS NOT NULL AND salespersonid != ?',
      whereArgs: [''],
      orderBy: 'username ASC',
    );
    return result.map((map) => map['username'] as String).toList();
  }

  Future<List<User>> getUsersByRole(String role) async {
    final db = database;
    final maps = await db.query('user', where: 'role = ?', whereArgs: [role]);
    return maps.map((map) => User.fromMap(map)).toList();
  }

  Future<List<User>> getUsersWithSalespersonId() async {
    final db = database;
    final maps = await db.query(
      'user',
      where: 'salespersonid IS NOT NULL AND salespersonid != ?',
      whereArgs: [''],
    );
    return maps.map((map) => User.fromMap(map)).toList();
  }

  Future<User?> authenticateUser(String role, int password) async {
    final db = database;
    final maps = await db.query(
      'user',
      where: 'role = ? AND pospassword = ?',
      whereArgs: [role, password],
      limit: 1,
    );
    return maps.isNotEmpty ? User.fromMap(maps.first) : null;
  }

  Future<User?> authenticateUserByUsername(String username, int password) async {
    final db = database;
    final maps = await db.query(
      'user',
      where: 'username = ? AND pospassword = ?',
      whereArgs: [username, password],
      limit: 1,
    );
    return maps.isNotEmpty ? User.fromMap(maps.first) : null;
  }

  Future<void> deleteAllUsers() async {
    final db = database;
    await db.delete('user');
  }

  // ========================================================================
  // POS SERVICE POINT METHODS
  // ========================================================================

  Future<int> insertServicePointModel(ServicePoint servicePoint) async {
    final db = database;
    return await db.insert('service_point', servicePoint.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> insertServicePoint(Map<String, dynamic> servicePoint) async {
    final db = database;
    return await db.insert('service_point', servicePoint, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertServicePointModels(List<ServicePoint> servicePoints) async {
    final db = database;
    final batch = db.batch();
    for (var sp in servicePoints) {
      batch.insert('service_point', sp.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> insertServicePoints(List<Map<String, dynamic>> servicePoints) async {
    final db = database;
    final batch = db.batch();
    for (var sp in servicePoints) {
      batch.insert('service_point', sp, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<ServicePoint>> getServicePoints() async {
    final db = database;
    final maps = await db.query('service_point');
    return maps.map((map) => ServicePoint.fromMap(map)).toList();
  }

  Future<List<ServicePoint>> getSalesServicePoints() async {
    final db = database;
    final maps = await db.query('service_point', where: 'sales = ?', whereArgs: [1]);
    return maps.map((map) => ServicePoint.fromMap(map)).toList();
  }

  Future<void> deleteAllServicePoints() async {
    final db = database;
    await db.delete('service_point');
  }

  // ========================================================================
  // POS INVENTORY METHODS
  // ========================================================================

  Future<int> insertInventoryItemModel(InventoryItem item) async {
    final db = database;
    return await db.insert('inventory', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> insertInventoryItem(Map<String, dynamic> item) async {
    final db = database;
    return await db.insert('inventory', item, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertInventoryItemModels(List<InventoryItem> items) async {
    final db = database;
    final batch = db.batch();
    for (var item in items) {
      batch.insert('inventory', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> insertInventoryItems(List<Map<String, dynamic>> items) async {
    final db = database;
    final batch = db.batch();
    for (var item in items) {
      batch.insert('inventory', item, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<InventoryItem>> getInventoryItems() async {
    final db = database;
    final maps = await db.query('inventory');
    return maps.map((map) => InventoryItem.fromMap(map)).toList();
  }

  Future<List<InventoryItem>> searchInventoryItems(String query) async {
    final db = database;
    final maps = await db.query(
      'inventory',
      where: 'name LIKE ? OR code LIKE ? OR category LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
    return maps.map((map) => InventoryItem.fromMap(map)).toList();
  }

  Future<List<InventoryItem>> getInventoryItemsByCategory(String category) async {
    final db = database;
    final maps = await db.query('inventory', where: 'category = ?', whereArgs: [category], orderBy: 'name ASC');
    return maps.map((map) => InventoryItem.fromMap(map)).toList();
  }

  Future<List<String>> getInventoryCategories() async {
    final db = database;
    final result = await db.query('inventory', columns: ['category'], distinct: true, orderBy: 'category ASC');
    return result.map((map) => map['category'] as String).toList();
  }

  Future<List<InventoryItem>> getInventoryItemsBySoldFrom(String soldFrom) async {
    final db = database;
    final maps = await db.query('inventory', where: 'soldfrom = ?', whereArgs: [soldFrom], orderBy: 'name ASC');
    return maps.map((map) => InventoryItem.fromMap(map)).toList();
  }

  Future<void> deleteAllInventoryItems() async {
    final db = database;
    await db.delete('inventory');
  }

  Future<int> getInventoryCount() async {
    final db = database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM inventory'));
    return count ?? 0;
  }

  // ========================================================================
  // POS SALES TRANSACTIONS METHODS
  // ========================================================================

  Future<int> insertSaleTransaction(Map<String, dynamic> transaction) async {
    final db = database;
    return await db.insert('sales_transactions', transaction, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertSaleTransactions(List<Map<String, dynamic>> transactions) async {
    final db = database;
    final batch = db.batch();
    for (var tx in transactions) {
      batch.insert('sales_transactions', tx, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<SaleTransaction>> getSaleTransactions() async {
    final db = database;
    final maps = await db.query('sales_transactions', orderBy: 'transactiondate DESC');
    return maps.map((map) => SaleTransaction.fromMap(map)).toList();
  }

  Future<List<SaleTransaction>> getSaleTransactionsBySalesId(String salesId) async {
    final db = database;
    final maps = await db.query('sales_transactions', where: 'salesId = ?', whereArgs: [salesId]);
    return maps.map((map) => SaleTransaction.fromMap(map)).toList();
  }

  Future<List<Map<String, dynamic>>> getGroupedSales() async {
    final db = database;
    return await db.rawQuery('''
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
  }

  Future<List<SaleTransaction>> getSaleTransactionsByDateRange(int startDate, int endDate) async {
    final db = database;
    final maps = await db.query(
      'sales_transactions',
      where: 'transactiondate BETWEEN ? AND ?',
      whereArgs: [startDate, endDate],
      orderBy: 'transactiondate DESC',
    );
    return maps.map((map) => SaleTransaction.fromMap(map)).toList();
  }

  Future<void> deleteAllSaleTransactions() async {
    final db = database;
    await db.delete('sales_transactions');
  }

  Future<int> getSalesCount() async {
    final db = database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(DISTINCT salesId) FROM sales_transactions'));
    return count ?? 0;
  }

  Future<void> updateSaleUploadStatus(String salesId, String status, {String? errorMessage}) async {
    final db = database;
    await db.update(
      'sales_transactions',
      {
        'upload_status': status,
        'uploaded_at': status == 'uploaded' ? DateTime.now().millisecondsSinceEpoch : null,
        'upload_error': errorMessage,
      },
      where: 'salesId = ?',
      whereArgs: [salesId],
    );
  }

  Future<List<Map<String, dynamic>>> getSalesByUploadStatus(String status) async {
    final db = database;
    return await db.rawQuery('''
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
  }

  Future<Map<String, dynamic>> getDailySummary(int date) async {
    final db = database;
    final startOfDay = DateTime.fromMillisecondsSinceEpoch(date);
    final startMillis = DateTime(startOfDay.year, startOfDay.month, startOfDay.day).millisecondsSinceEpoch;
    final endMillis = DateTime(startOfDay.year, startOfDay.month, startOfDay.day, 23, 59, 59).millisecondsSinceEpoch;

    final paymentSummary = await db.rawQuery('''
      SELECT paymenttype, SUM(amountpaid) as totalPaid
      FROM sales_transactions
      WHERE transactiondate BETWEEN ? AND ?
      GROUP BY paymenttype
    ''', [startMillis, endMillis]);

    final categorySummary = await db.rawQuery('''
      SELECT category, SUM(amount) as totalAmount
      FROM sales_transactions
      WHERE transactiondate BETWEEN ? AND ?
      GROUP BY category
    ''', [startMillis, endMillis]);

    final complementaryTotal = await db.rawQuery('''
      SELECT SUM(amount) as total
      FROM sales_transactions
      WHERE transactiondate BETWEEN ? AND ? AND complimentaryid > 0
    ''', [startMillis, endMillis]);

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

  // ========================================================================
  // POS CASH ACCOUNTS METHODS
  // ========================================================================

  Future<void> insertCashAccounts(List<Map<String, dynamic>> accounts) async {
    final db = database;
    final batch = db.batch();
    await db.delete('cash_accounts');
    for (final a in accounts) {
      batch.insert('cash_accounts', {
        'id': a['id'],
        'accountname': a['accountname'],
        'accountnumber': a['accountnumber'],
        'reference': a['reference'],
        'paymentmode_code': a['paymentMode']?['code'],
        'paymentmode_name': a['paymentMode']?['name'],
        'currency_id': a['currency']?['id'],
        'currency_code': a['currency']?['code'],
        'currency_name': a['currency']?['name'],
        'main_currency': a['currency']?['mainCurrency'] == true ? 1 : 0,
        'branchid': a['branch'],
        'companyid': a['company'],
        'pos': a['pos'] == true ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<String?> getDefaultCurrencyId() async {
    final db = database;
    final result = await db.query(
      'cash_accounts',
      columns: ['currency_id'],
      where: 'pos = 1 AND main_currency = 1',
      limit: 1,
    );
    return result.isNotEmpty ? result.first['currency_id'] as String : null;
  }

  // ========================================================================
  // POS CUSTOMERS METHODS
  // ========================================================================

  Future<int> insertCustomerModel(Customer customer) async {
    final db = database;
    return await db.insert('customers', customer.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> insertCustomer(Map<String, dynamic> customer) async {
    final db = database;
    return await db.insert('customers', customer, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertCustomers(List<Customer> customers) async {
    final db = database;
    final batch = db.batch();
    for (var c in customers) {
      batch.insert('customers', c.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Customer>> getCustomers() async {
    final db = database;
    final maps = await db.query('customers', orderBy: 'fullnames ASC');
    return maps.map((map) => Customer.fromMap(map)).toList();
  }

  Future<List<Customer>> searchCustomers(String query) async {
    final db = database;
    final maps = await db.query(
      'customers',
      where: 'fullnames LIKE ? OR phone1 LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'fullnames ASC',
    );
    return maps.map((map) => Customer.fromMap(map)).toList();
  }

  Future<Customer?> getCustomerById(String id) async {
    final db = database;
    final maps = await db.query('customers', where: 'id = ?', whereArgs: [id], limit: 1);
    return maps.isNotEmpty ? Customer.fromMap(maps.first) : null;
  }

  Future<void> deleteAllCustomers() async {
    final db = database;
    await db.delete('customers');
  }

  Future<int> getCustomerCount() async {
    final db = database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM customers'));
    return count ?? 0;
  }

  // ========================================================================
  // POS SYNC METADATA METHODS
  // ========================================================================

  Future<void> updateSyncMetadata(String dataType, String status, int recordCount, [String? errorMessage]) async {
    final db = database;
    await db.insert('sync_metadata', {
      'data_type': dataType,
      'last_sync_timestamp': DateTime.now().millisecondsSinceEpoch,
      'sync_status': status,
      'record_count': recordCount,
      'error_message': errorMessage,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getSyncMetadata(String dataType) async {
    final db = database;
    final result = await db.query('sync_metadata', where: 'data_type = ?', whereArgs: [dataType], limit: 1);
    return result.isNotEmpty ? result.first : null;
  }

  Future<bool> hasCachedData(String dataType) async {
    if (!isDatabaseOpen) return false;
    final db = database;
    int count = 0;
    try {
      switch (dataType) {
        case 'users':
          count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM user')) ?? 0;
          break;
        case 'service_points':
          count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM service_point')) ?? 0;
          break;
        case 'inventory':
          count = await getInventoryCount();
          break;
        case 'sales_transactions':
          count = await getSalesCount();
          break;
        case 'customers':
          count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM customers')) ?? 0;
          break;
      }
    } catch (e) {
      return false;
    }
    return count > 0;
  }

  // ========================================================================
  // POS SERVER SALES METHODS
  // ========================================================================

  Future<void> insertServerSales(List<Map<String, dynamic>> salesData) async {
    final db = database;
    final batch = db.batch();
    await db.delete('server_sales');
    for (var sale in salesData) {
      batch.insert('server_sales', sale, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<Map<String, dynamic>?> getServerSaleBySalesId(String salesId) async {
    final db = database;
    final maps = await db.query('server_sales', where: 'salesId = ?', whereArgs: [salesId], limit: 1);
    return maps.isNotEmpty ? maps.first : null;
  }

  Future<void> syncLocalSalesWithServerData() async {
    final db = database;
    final localSalesIds = await db.rawQuery('SELECT DISTINCT salesId FROM sales_transactions');

    for (var row in localSalesIds) {
      final salesId = row['salesId'] as String;
      final serverSale = await getServerSaleBySalesId(salesId);

      if (serverSale != null) {
        final serverAmountPaid = (serverSale['amountpaid'] as num?)?.toDouble() ?? 0.0;
        final serverBalance = (serverSale['balance'] as num?)?.toDouble() ?? 0.0;
        final serverPaymentMode = serverSale['paymentmode'] as String? ?? 'Cash';

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
      }
    }
  }

  Future<int> getServerSalesCount() async {
    final db = database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM server_sales'));
    return count ?? 0;
  }

  Future<void> deleteAllServerSales() async {
    final db = database;
    await db.delete('server_sales');
  }

  // ========================================================================
  // MONITOR SERVICE POINTS METHODS (mon_service_points)
  // ========================================================================

  Future<void> insertMonServicePoint(Map<String, dynamic> servicePoint, {DatabaseExecutor? db}) async {
    final executor = db ?? database;
    await executor.insert('mon_service_points', {
      'id': servicePoint['id'],
      'name': servicePoint['name'],
      'code': servicePoint['code'],
      'branch': servicePoint['branch'],
      'company': servicePoint['company'],
      'mainServicePoint': servicePoint['mainServicePoint'] == true ? 1 : 0,
      'stores': servicePoint['stores'] == true ? 1 : 0,
      'sales': servicePoint['sales'] == true ? 1 : 0,
      'production': servicePoint['production'] == true ? 1 : 0,
      'booking': servicePoint['booking'] == true ? 1 : 0,
      'servicePointTypeId': servicePoint['servicePointTypeId'],
      'departmentid': servicePoint['departmentid'],
      'facilityName': servicePoint['name'],
      'facilityCode': servicePoint['facility']?['code'],
      'fullName': servicePoint['fullName'],
      'servicepointtype': servicePoint['servicepointtype'],
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getMonServicePoints() async {
    final db = database;
    return await db.query('mon_service_points');
  }

  Future<String?> getMonServicePointIdByName(String name, {DatabaseExecutor? db}) async {
    final executor = db ?? database;
    final result = await executor.query('mon_service_points', where: 'name = ?', whereArgs: [name]);
    return result.isNotEmpty ? result.first['id'] as String? : null;
  }

  Future<void> deleteAllMonServicePoints() async {
    final db = database;
    await db.delete('mon_service_points');
  }

  // ========================================================================
  // MONITOR COMPANY DETAILS METHODS
  // ========================================================================

  Future<void> insertCompanyDetails(Map<String, dynamic> companyDetails, {DatabaseExecutor? db}) async {
    final executor = db ?? database;
    await executor.insert('company_details', {
      'branch': companyDetails['branch'],
      'company': companyDetails['company'],
      'userCode': companyDetails['userCode'],
      'currentBranchName': companyDetails['currentBranchName'],
      'currentBranchCode': companyDetails['currentBranchCode'],
      'activeBranchName': companyDetails['activeBranch']?['name'],
      'activeBranchAddress': companyDetails['activeBranch']?['address'],
      'activeBranchPrimaryEmail': companyDetails['activeBranch']?['primaryEmail'],
      'activeBranchCode': companyDetails['activeBranch']?['code'],
      'efrisEnabled': companyDetails['efrisEnabled'] == true ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getCompanyDetails() async {
    final db = database;
    final result = await db.query('company_details', limit: 1);
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> deleteAllCompanyDetails() async {
    final db = database;
    await db.delete('company_details');
  }

  // ========================================================================
  // MONITOR SALES METHODS (mon_sales)
  // ========================================================================

  Future<void> insertMonSale(Map<String, dynamic> sale, {DatabaseExecutor? db}) async {
    final executor = db ?? database;
    Map<String, dynamic> toInsert = {};

    if (sale.containsKey('id')) toInsert['id'] = sale['id'];
    if (sale.containsKey('purchaseordernumber')) toInsert['purchaseordernumber'] = sale['purchaseordernumber'];
    if (sale.containsKey('internalrefno')) toInsert['internalrefno'] = sale['internalrefno'];
    if (sale.containsKey('issuedby')) toInsert['issuedby'] = sale['issuedby'];
    if (sale.containsKey('receiptnumber')) toInsert['receiptnumber'] = sale['receiptnumber'];
    if (sale.containsKey('receivedby')) toInsert['receivedby'] = sale['receivedby'];
    if (sale.containsKey('remarks')) toInsert['remarks'] = sale['remarks'];
    if (sale.containsKey('transactiondate')) toInsert['transactiondate'] = sale['transactiondate'];
    if (sale.containsKey('costcentre')) toInsert['costcentre'] = sale['costcentre'];
    if (sale.containsKey('destinationbp')) toInsert['destinationbp'] = sale['destinationbp'];
    if (sale.containsKey('paymentmode')) toInsert['paymentmode'] = sale['paymentmode'];
    if (sale.containsKey('sourcefacility')) toInsert['sourcefacility'] = sale['sourcefacility'];
    if (sale.containsKey('genno')) toInsert['genno'] = sale['genno'];
    if (sale.containsKey('paymenttype')) toInsert['paymenttype'] = sale['paymenttype'];
    if (sale.containsKey('validtill')) toInsert['validtill'] = sale['validtill'];
    if (sale.containsKey('currency')) toInsert['currency'] = sale['currency'];
    if (sale.containsKey('quantity')) toInsert['quantity'] = sale['quantity'];
    if (sale.containsKey('unitquantity')) toInsert['unitquantity'] = sale['unitquantity'];
    if (sale.containsKey('amount')) toInsert['amount'] = sale['amount'];
    if (sale.containsKey('amountpaid')) toInsert['amountpaid'] = sale['amountpaid'];
    if (sale.containsKey('balance')) toInsert['balance'] = sale['balance'];
    if (sale.containsKey('sellingprice')) toInsert['sellingprice'] = sale['sellingprice'];
    if (sale.containsKey('costprice')) toInsert['costprice'] = sale['costprice'];
    if (sale.containsKey('sellingprice_original')) toInsert['sellingprice_original'] = sale['sellingprice_original'];
    if (sale.containsKey('inventoryname')) toInsert['inventoryname'] = sale['inventoryname'];
    if (sale.containsKey('category')) toInsert['category'] = sale['category'];
    if (sale.containsKey('subcategory')) toInsert['subcategory'] = sale['subcategory'];
    if (sale.containsKey('gnrtd')) toInsert['gnrtd'] = (sale['gnrtd'] == 1 || sale['gnrtd'] == true) ? 1 : 0;
    if (sale.containsKey('printed')) toInsert['printed'] = (sale['printed'] == 1 || sale['printed'] == true) ? 1 : 0;
    if (sale.containsKey('redeemed')) toInsert['redeemed'] = (sale['redeemed'] == 1 || sale['redeemed'] == true) ? 1 : 0;
    if (sale.containsKey('cancelled')) toInsert['cancelled'] = (sale['cancelled'] == 1 || sale['cancelled'] == true) ? 1 : 0;
    if (sale.containsKey('patron')) toInsert['patron'] = sale['patron'];
    if (sale.containsKey('department')) toInsert['department'] = sale['department'];
    if (sale.containsKey('packsize')) toInsert['packsize'] = sale['packsize'];
    if (sale.containsKey('packaging')) toInsert['packaging'] = sale['packaging'];
    if (sale.containsKey('complimentaryid')) toInsert['complimentaryid'] = sale['complimentaryid'];
    if (sale.containsKey('salesId')) toInsert['salesId'] = sale['salesId'];
    if (sale.containsKey('service_point_id')) toInsert['service_point_id'] = sale['service_point_id'];
    if (sale.containsKey('salesperson')) toInsert['salesperson'] = sale['salesperson'];

    await executor.insert('mon_sales', toInsert, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getMonSales() async {
    final db = database;
    return await db.query('mon_sales', orderBy: 'transactiondate DESC');
  }

  Future<List<Map<String, dynamic>>> getMonSalesByDateRange(int startDate, int endDate) async {
    final db = database;
    return await db.query(
      'mon_sales',
      where: 'transactiondate BETWEEN ? AND ?',
      whereArgs: [startDate, endDate],
      orderBy: 'transactiondate DESC',
    );
  }

  Future<void> deleteAllMonSales() async {
    final db = database;
    await db.delete('mon_sales');
  }

  Future<void> mapMonSalesToServicePoints({DatabaseExecutor? db}) async {
    final executor = db ?? database;
    final sales = await executor.query('mon_sales');

    for (final sale in sales) {
      final sourceFacility = sale['sourcefacility'] as String?;
      if (sourceFacility == null) continue;

      final servicePoints = await executor.query(
        'mon_service_points',
        where: '(name = ? OR fullName = ?)',
        whereArgs: [sourceFacility, sourceFacility],
      );

      if (servicePoints.isNotEmpty) {
        final servicePointId = servicePoints.first['id'] as String?;
        if (servicePointId != null) {
          await executor.update(
            'mon_sales',
            {'service_point_id': servicePointId},
            where: 'id = ?',
            whereArgs: [sale['id']],
          );
        }
      }
    }
  }

  // ========================================================================
  // MONITOR INVENTORY METHODS (mon_inventory)
  // ========================================================================

  Future<void> insertMonInventoryItem(Map<String, dynamic> item, {DatabaseExecutor? db}) async {
    final executor = db ?? database;
    await executor.insert('mon_inventory', {
      'id': item['id'],
      'ipdid': item['ipdid'],
      'code': item['code'],
      'externalserial': item['externalserial'],
      'name': item['name'],
      'category': item['category'],
      'price': item['price'],
      'packsize': item['packsize'],
      'packaging': item['packaging'],
      'packagingid': item['packagingid'],
      'soldfrom': item['soldfrom'],
      'shortform': item['shortform'],
      'packagingcode': item['packagingcode'],
      'efris': item['efris'] == true ? 1 : 0,
      'efrisid': item['efrisid'],
      'measurmentunitidefris': item['measurmentunitidefris'],
      'measurmentunit': item['measurmentunit'],
      'measurmentunitid': item['measurmentunitid'],
      'vatcategoryid': item['vatcategoryid'],
      'branchid': item['branchid'],
      'companyid': item['companyid'],
      'downloadlink': item['downloadlink'],
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getMonInventoryItems() async {
    final db = database;
    return await db.query('mon_inventory');
  }

  Future<void> deleteAllMonInventoryItems() async {
    final db = database;
    await db.delete('mon_inventory');
  }

  // ========================================================================
  // UTILITY METHODS
  // ========================================================================

  Future<List<Map<String, dynamic>>> getMonSalesTableSchema() async {
    final db = database;
    return await db.rawQuery('PRAGMA table_info(mon_sales)');
  }

  /// Execute raw query (for complex operations)
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    final db = database;
    return await db.rawQuery(sql, arguments);
  }

  /// Execute raw statement (for complex operations)
  Future<void> rawExecute(String sql, [List<Object?>? arguments]) async {
    final db = database;
    await db.execute(sql, arguments);
  }

  /// Run operations in a transaction
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = database;
    return await db.transaction(action);
  }
}
