import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class CrimeDbHelper {
  CrimeDbHelper._();
  static final CrimeDbHelper instance = CrimeDbHelper._();

  static const _dbName = 'crime.db';
  static const _dbVersion = 4; // ↑ bump jika ubah skema

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    try {
      final dbDir = await getDatabasesPath();             // ✅ aman untuk Android/iOS
      final path = p.join(dbDir, _dbName);

      return await openDatabase(
        path,
        version: _dbVersion,
        onCreate: (db, v) async {
          await db.execute('''
            CREATE TABLE crime_reports (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              title TEXT NOT NULL,
              description TEXT,
              location TEXT,
              date TEXT,
              severity TEXT,
              resolved INTEGER,
              photo_path TEXT
            )
          ''');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_crime_name ON crime_reports(name)');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_crime_date ON crime_reports(date)');
        },
        onUpgrade: (db, oldV, newV) async {
          // ✅ upgrade bertahap + guard kolom agar tidak crash kalau sudah ada
          if (oldV < 2) {
            final hasName = await _columnExists(db, 'crime_reports', 'name');
            if (!hasName) {
              await db.execute('ALTER TABLE crime_reports ADD COLUMN name TEXT DEFAULT ""');
            }
          }
          if (oldV < 3) {
            final hasPhoto = await _columnExists(db, 'crime_reports', 'photo_path');
            if (!hasPhoto) {
              await db.execute('ALTER TABLE crime_reports ADD COLUMN photo_path TEXT');
            }
          }
        },
      );
    } catch (e, st) {
      // 👇 bantu trace error asli di logcat
      // (bisa print atau menggunakan logger kamu)
      // ignore: avoid_print
      print('DB OPEN ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<bool> _columnExists(Database db, String table, String column) async {
    final res = await db.rawQuery('PRAGMA table_info($table)');
    for (final row in res) {
      if ((row['name'] as String?)?.toLowerCase() == column.toLowerCase()) {
        return true;
      }
    }
    return false;
  }
}
