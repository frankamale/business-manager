import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:get/get.dart';
import '../services/api_services.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();


  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  // Map to store database instances by company ID
  static final Map<String, Database> _databases = {};
  static String? _currentCompanyId;

  Future<Database> get database async {
    // Get current company ID
    final companyId = await _getCurrentCompanyId();
    
    // Check if we already have a database instance for this company
    if (_databases.containsKey(companyId)) {
      return _databases[companyId]!;
    }
    
    // Initialize new database for this company
    final db = await _initDb(companyId);
    _databases[companyId] = db;
    _currentCompanyId = companyId;
    return db;
  }

  Future<Database> _initDb(String companyId) async {
    // Sanitize company ID for use in database name
    final sanitizedCompanyId = _sanitizeCompanyId(companyId);
    
    // Create company-specific database name
    final dbName = 'app_database_$sanitizedCompanyId.db';
    String path = join(await getDatabasesPath(), dbName);
    
    return await openDatabase(path, version: 7, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<String> _getCurrentCompanyId() async {
    try {
      final apiService = Get.find<MonitorApiService>();
      return await apiService.ensureCompanyIdAvailable();
    } catch (e) {
      // If company ID is not available, use a default
      print("DatabaseHelper: Company ID not available, using default: $e");
      return 'default';
    }
  }

  String _sanitizeCompanyId(String companyId) {
    // Remove any characters that might cause issues in filenames
    return companyId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  }

  /// Switch to a different company's database
  /// This will close the current database and open the one for the specified company
  Future<void> switchCompany(String newCompanyId) async {
    final sanitizedCompanyId = _sanitizeCompanyId(newCompanyId);
    
    // If we're already using this company, do nothing
    if (_currentCompanyId == sanitizedCompanyId) {
      return;
    }
    
    // Close the current database if it exists
    if (_currentCompanyId != null && _databases.containsKey(_currentCompanyId)) {
      try {
        await _databases[_currentCompanyId]!.close();
        _databases.remove(_currentCompanyId);
      } catch (e) {
        print("DatabaseHelper: Error closing database for company $_currentCompanyId: $e");
      }
    }
    
    // Open the database for the new company
    _currentCompanyId = sanitizedCompanyId;
  }

  /// Close all database instances
  Future<void> closeAllDatabases() async {
    for (final entry in _databases.entries) {
      try {
        await entry.value.close();
      } catch (e) {
        print("DatabaseHelper: Error closing database for company ${entry.key}: $e");
      }
    }
    _databases.clear();
    _currentCompanyId = null;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS  service_points(
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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS  company_details(
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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS  sales(
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

    await db.execute('''
  CREATE TABLE IF NOT EXISTS  inventory(
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
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 5) {
      await db.execute(
          'ALTER TABLE sales ADD COLUMN service_point_id TEXT'
      );
    }

    if (oldVersion < 6) {
      await db.execute(
          'ALTER TABLE sales ADD COLUMN salesperson TEXT'
      );
    }


  }

  Future<String?> getServicePointIdByName(
    String name, {
    DatabaseExecutor? db,
  }) async {
    final executor = db ?? await database;
    final result = await executor.query(
      'service_points',
      where: 'name = ? ',
      whereArgs: [name],
    );
    return result.isNotEmpty ? result.first['id'] as String? : null;
  }

  Future<void> insertServicePoint(
    Map<String, dynamic> servicePoint, {
    DatabaseExecutor? db,
  }) async {
    final executor = db ?? await database;
    await executor.insert('service_points', {
      'id': servicePoint['id'],
      'name': servicePoint['name'],
      'code': servicePoint['code'],
      'branch': servicePoint['branch'],
      'company': servicePoint['company'],
      'mainServicePoint': servicePoint['mainServicePoint'] ? 1 : 0,
      'stores': servicePoint['stores'] ? 1 : 0,
      'sales': servicePoint['sales'] ? 1 : 0,
      'production': servicePoint['production'] ? 1 : 0,
      'booking': servicePoint['booking'] ? 1 : 0,
      'servicePointTypeId': servicePoint['servicePointTypeId'],
      'departmentid': servicePoint['departmentid'],
      'facilityName': servicePoint['name'],
      'facilityCode': servicePoint['facility']?['code'],
      'fullName': servicePoint['fullName'],
      'servicepointtype': servicePoint['servicepointtype'],
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertCompanyDetails(
    Map<String, dynamic> companyDetails, {
    DatabaseExecutor? db,
  }) async {
    final executor = db ?? await database;
    await executor.insert('company_details', {
      'branch': companyDetails['branch'],
      'company': companyDetails['company'],
      'userCode': companyDetails['userCode'],
      'currentBranchName': companyDetails['currentBranchName'],
      'currentBranchCode': companyDetails['currentBranchCode'],
      'activeBranchName': companyDetails['activeBranch']?['name'],
      'activeBranchAddress': companyDetails['activeBranch']?['address'],
      'activeBranchPrimaryEmail':
          companyDetails['activeBranch']?['primaryEmail'],
      'activeBranchCode': companyDetails['activeBranch']?['code'],
      'efrisEnabled': companyDetails['efrisEnabled'] ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertSale(
    Map<String, dynamic> sale, {
    DatabaseExecutor? db,
  }) async {
    final executor = db ?? await database;
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


    await executor.insert('sales', toInsert, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertInventoryItem(
    Map<String, dynamic> item, {
    DatabaseExecutor? db,
  }) async {
    final executor = db ?? await database;
    await executor.insert('inventory', {
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
      'efris': item['efris'] ? 1 : 0,
      'efrisid': item['efrisid'],
      'measurmentunitidefris': item['measurmentunitidefris'],
      'measurmentunit': item['measurmentunit'],
      'measurmentunitid': item['measurmentunitid'],
      'vatcategoryid': item['vatcategoryid'],
      'branchid': item['branchid'],
      'companyid': item['companyid'],
      'downloadlink': item['downloadlink']
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAllInventoryItems() async {
    final db = await database;
    return await db.query(
        'inventory',


    );
  }

  Future<void> mapSalesToServicePoints({DatabaseExecutor? db}) async {
    final executor = db ?? await database;
    final sales = await executor.query(
      'sales',

    );    for (final sale in sales) {
      final sourceFacility = sale['sourcefacility'] as String?;
      if (sourceFacility == null) continue;
      final servicePoints = await executor.query(
        'service_points',
        where: '(name = ? OR fullName = ?) ',
        whereArgs: [sourceFacility, sourceFacility],
      );
      if (servicePoints.isNotEmpty) {
        final servicePointId = servicePoints.first['id'] as String?;
        if (servicePointId != null) {
          await executor.update(
            'sales',
            {'service_point_id': servicePointId},
            where: 'id = ?',
            whereArgs: [sale['id']],
          );
        }
      }
    }
  }

  Future<List<Map<String, dynamic>>> getSalesTableSchema() async {
    final db = await database;
    return await db.rawQuery('PRAGMA table_info(sales)');
  }

  Future<Map<String, dynamic>?> getCompanyDetails() async {
    final db = await database;
    final result = await db.query('company_details', limit: 1);
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  Future<void> testSalesMapping() async {
    final db = await database;
    final sales = await db.query('sales', limit: 5);
    for (final sale in sales) {
      print('sourcefacility: ${sale['sourcefacility']}, service_point_id: ${sale['service_point_id']}');
    }
  }
}
