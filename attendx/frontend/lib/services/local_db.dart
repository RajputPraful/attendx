import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDb {
  static final LocalDb instance = LocalDb._init();
  static Database? _database;

  LocalDb._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('attendx.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE semesters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT DEFAULT 'Current Semester',
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        saturday_enabled INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE subjects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        code TEXT,
        required_percentage REAL DEFAULT 75.0,
        color TEXT DEFAULT '#6750A4',
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE timetable_versions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label TEXT DEFAULT 'Timetable',
        effective_from TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE class_slots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timetable_version_id INTEGER NOT NULL,
        subject_id INTEGER NOT NULL,
        day_of_week INTEGER NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        duration_hours REAL NOT NULL,
        FOREIGN KEY (timetable_version_id) REFERENCES timetable_versions (id) ON DELETE CASCADE,
        FOREIGN KEY (subject_id) REFERENCES subjects (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_slot_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'PRESENT',
        units REAL NOT NULL DEFAULT 1.0,
        auto_marked INTEGER DEFAULT 1,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(class_slot_id, date),
        FOREIGN KEY (class_slot_id) REFERENCES class_slots (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Default period duration = 50 minutes
    await db.insert('settings', {'key': 'period_duration_minutes', 'value': '50'});

    // Default semester
    final now = DateTime.now();
    await db.insert('semesters', {
      'start_date': DateTime(now.year, now.month, 1).toIso8601String().split('T').first,
      'end_date': DateTime(now.year, now.month + 4, 1).toIso8601String().split('T').first,
      'saturday_enabled': 0,
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Create settings table for users upgrading from v1
      await db.execute('''
        CREATE TABLE IF NOT EXISTS settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
      await db.insert(
        'settings',
        {'key': 'period_duration_minutes', 'value': '50'},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  // --- Settings ---
  Future<int> getPeriodDurationMinutes() async {
    final db = await instance.database;
    final res = await db.query('settings', where: 'key = ?', whereArgs: ['period_duration_minutes']);
    if (res.isEmpty) return 50;
    return int.tryParse(res.first['value'] as String) ?? 50;
  }

  Future<void> setPeriodDurationMinutes(int minutes) async {
    final db = await instance.database;
    await db.insert(
      'settings',
      {'key': 'period_duration_minutes', 'value': minutes.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- CRUD Methods ---
  Future<List<Map<String, dynamic>>> getSubjects() async {
    final db = await instance.database;
    return await db.query('subjects', where: 'is_deleted = 0');
  }

  Future<int> insertSubject(Map<String, dynamic> subject) async {
    final db = await instance.database;
    return await db.insert('subjects', subject);
  }

  Future<int> updateSubject(int id, Map<String, dynamic> subject) async {
    final db = await instance.database;
    return await db.update('subjects', subject, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteSubject(int id) async {
    final db = await instance.database;
    return await db.update('subjects', {'is_deleted': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> getSemester() async {
    final db = await instance.database;
    final res = await db.query('semesters', where: 'is_active = 1', limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  Future<int> setSemester(Map<String, dynamic> semester) async {
    final db = await instance.database;
    await db.update('semesters', {'is_active': 0});
    semester['is_active'] = 1;
    return await db.insert('semesters', semester);
  }

  Future<List<Map<String, dynamic>>> getTimetableVersions() async {
    final db = await instance.database;
    return await db.query('timetable_versions', orderBy: 'effective_from DESC, id DESC');
  }

  Future<void> createTimetableVersion(Map<String, dynamic> version, List<Map<String, dynamic>> slots) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      final vId = await txn.insert('timetable_versions', version);
      for (var slot in slots) {
        slot['timetable_version_id'] = vId;
        await txn.insert('class_slots', slot);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getSlotsForVersion(int versionId) async {
    final db = await instance.database;
    return await db.query('class_slots', where: 'timetable_version_id = ?', whereArgs: [versionId]);
  }
}
