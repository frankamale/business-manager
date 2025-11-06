import 'package:bac_pos/models/users.dart';
import 'package:bac_pos/models/service_point.dart';
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
      version: 3,  // Incremented version to add service points table
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
}
