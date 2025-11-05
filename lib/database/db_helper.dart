import 'package:bac_pos/models/users.dart';
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
    return await openDatabase(path, version: 1, onCreate: _onCreate);
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
      pospassword TEXT
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
    final List<Map<String, dynamic>> maps = await db!.query('users');
    return List.generate(maps.length, (i) {
      return User.fromMap(maps[i]);
    });
  }
}
