import 'package:sqflite/sqflite.dart';
import '../models/crime_report.dart';
import 'crime_db_helper.dart';
import 'crime_repository.dart';
import 'dart:io';

class CrimeSqliteRepository implements ICrimeRepository {
  CrimeSqliteRepository._();
  static final CrimeSqliteRepository instance = CrimeSqliteRepository._();

  Future<Database> get _db async => await CrimeDbHelper.instance.database;

  @override
  Future<List<CrimeReport>> all() async {
    final rows = await (await _db).query('crime_reports', orderBy: 'date DESC');
    return rows.map((m) => CrimeReport.fromMap(m)).toList();
  }

  // 🔎 Tambahkan: search by name (LIKE) + date range (opsional)
  Future<List<CrimeReport>> search({
    String? name,
    DateTime? from,
    DateTime? to,
  }) async {
    final where = <String>[];
    final args = <Object?>[];

    if (name != null && name.trim().isNotEmpty) {
      where.add('LOWER(name) LIKE ?');
      args.add('%${name.toLowerCase()}%');
    }
    if (from != null) {
      where.add('date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('date <= ?');
      args.add(to.toIso8601String());
    }

    final rows = await (await _db).query(
      'crime_reports',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'date DESC',
    );
    return rows.map((m) => CrimeReport.fromMap(m)).toList();
  }


  /// Bersihkan baris yang 'photo_path'-nya tidak bisa dipakai lagi.
  /// Return jumlah baris yang difix.
  Future<int> fixInvalidPhotoPaths() async {
    final db = await _db;
    final rows = await db.query(
      'crime_reports',
      columns: ['id', 'photo_path'],
    );

    int fixed = 0;
    for (final r in rows) {
      final id = r['id'] as String;
      final path = r['photo_path'] as String?;

      if (path == null || path.trim().isEmpty) continue;

      final isContentUri = path.startsWith('content://'); // tidak bisa dipakai langsung
      final exists = !isContentUri && File(path).existsSync();

      if (!exists) {
        await db.update(
          'crime_reports',
          {'photo_path': null},
          where: 'id = ?',
          whereArgs: [id],
        );
        fixed++;
      }
    }
    return fixed;
  }
  

  @override
  Future<CrimeReport> create(CrimeReport report) async {
    await (await _db).insert(
      'crime_reports',
      report.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return report;
  }

  @override
  Future<void> update(CrimeReport report) async {
    await (await _db).update(
      'crime_reports',
      report.toMap(),                 // <-- pastikan toMap menyertakan 'photo_path'
      where: 'id = ?',
      whereArgs: [report.id],
    );
  }

  @override
  Future<void> delete(String id) async {
    await (await _db).delete('crime_reports', where: 'id = ?', whereArgs: [id]);
  }
}
