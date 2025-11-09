import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class CrimeDbHelper {
  CrimeDbHelper._();
  static final CrimeDbHelper instance = CrimeDbHelper._();

  static const _dbName = 'crime_2.db';
  static const _dbVersion = 5;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  // ✅ METHOD UNTUK RESET DATABASE
  Future<void> resetDatabase() async {
    final dbDir = await getDatabasesPath();
    final path = p.join(dbDir, _dbName);
    
    // Tutup koneksi database yang ada
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    
    // Hapus file database
    await deleteDatabase(path);
    
    // Buka database baru
    _db = await _open();
  }

  Future<Database> _open() async {
    try {
      final dbDir = await getDatabasesPath();
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
          if (oldV < 3) {
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

  // ✅ METHOD UNTUK CEK VERSI DATABASE
  Future<int?> getDatabaseVersion() async {
    final db = await database;
    try {
      final result = await db.rawQuery('PRAGMA user_version');
      return result.first['user_version'] as int?;
    } catch (e) {
      return null;
    }
  }

  // ✅ METHOD UNTUK CEK STRUKTUR TABEL
  Future<void> debugTableStructure() async {
    final db = await database;
    print('=== DATABASE DEBUG INFO ===');
    
    // Cek versi
    final version = await getDatabaseVersion();
    print('Database Version: $version');
    
    // Cek struktur tabel crime_reports
    final tableInfo = await db.rawQuery('PRAGMA table_info(crime_reports)');
    print('Table crime_reports structure:');
    for (final column in tableInfo) {
      print('  ${column['name']} - ${column['type']}');
    }
    
    // Cek data yang ada
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM crime_reports'));
    print('Total records: $count');
  }
}