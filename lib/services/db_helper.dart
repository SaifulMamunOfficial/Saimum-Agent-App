import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('academy_offline.db');
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

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE offline_attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id TEXT NOT NULL,
        department_id INTEGER NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertAttendance(String studentId, int departmentId) async {
    final db = await instance.database;
    final data = {
      'student_id': studentId,
      'department_id': departmentId,
      'timestamp': DateTime.now().toIso8601String(),
    };
    return await db.insert('offline_attendance', data);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedAttendance() async {
    final db = await instance.database;
    return await db.query('offline_attendance');
  }

  Future<void> deleteAttendance(int id) async {
    final db = await instance.database;
    await db.delete(
      'offline_attendance',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
