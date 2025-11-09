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

    // ✅ GET dengan pagination
  Future<List<CrimeReport>> getCrimesPaginated({
    int limit = 50,
    int offset = 0,
    String? name,
    DateTime? from,
    DateTime? to,
    String sortBy = 'date',
    bool sortDesc = true,
  }) async {
    final db = await CrimeDbHelper.instance.database;
    
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];
    
    // Filter name
    if (name != null && name.isNotEmpty) {
      whereClauses.add('name LIKE ?');
      whereArgs.add('%$name%');
    }
    
    // Filter date range
    if (from != null) {
      whereClauses.add('date >= ?');
      whereArgs.add(from.toIso8601String());
    }
    
    if (to != null) {
      whereClauses.add('date <= ?');
      whereArgs.add(to.toIso8601String());
    }
    
    final where = whereClauses.isNotEmpty 
        ? 'WHERE ${whereClauses.join(' AND ')}' 
        : '';
    
    final orderBy = '$sortBy ${sortDesc ? 'DESC' : 'ASC'}';
    
    final maps = await db.rawQuery('''
      SELECT * FROM crime_reports 
      $where 
      ORDER BY $orderBy 
      LIMIT $limit OFFSET $offset
    ''', whereArgs);
    
    return maps.map((map) => CrimeReport.fromMap(map)).toList();
  }
  
  // ✅ COUNT dengan filter yang sama
  Future<int> getCrimesCount({
    String? name,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await CrimeDbHelper.instance.database;
    
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];
    
    if (name != null && name.isNotEmpty) {
      whereClauses.add('name LIKE ?');
      whereArgs.add('%$name%');
    }
    
    if (from != null) {
      whereClauses.add('date >= ?');
      whereArgs.add(from.toIso8601String());
    }
    
    if (to != null) {
      whereClauses.add('date <= ?');
      whereArgs.add(to.toIso8601String());
    }
    
    final where = whereClauses.isNotEmpty 
        ? 'WHERE ${whereClauses.join(' AND ')}' 
        : '';
    
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM crime_reports $where',
      whereArgs
    );
    
    return result.first['count'] as int;
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

  // Tambahkan di CrimeSqliteRepository atau CrimeDbHelper
Future<void> insertSampleData(int count) async {
  final db = await CrimeDbHelper.instance.database;
  
  final List<Map<String, dynamic>> sampleData = [];
  final List<String> names = ['Budi', 'Susi', 'Ahmad', 'Dewi', 'Rudi', 'Maya'];
  final List<String> titles = ['Pencurian', 'Penipuan', 'Penganiayaan', 'Narkoba', 'Korupsi'];
  final List<String> locations = ['Jakarta', 'Bandung', 'Surabaya', 'Medan', 'Makassar'];
  final List<String> severities = ['low', 'medium', 'high'];
  
  for (int i = 0; i < count; i++) {
    final random = DateTime.now().microsecondsSinceEpoch + i;
    
    sampleData.add({
      'id': 'sample_$i$random',
      'name': names[i % names.length],
      'title': '${titles[i % titles.length]} ${i + 1}',
      'description': 'Deskripsi untuk laporan ke-${i + 1}. Ini adalah data sample untuk testing.',
      'location': locations[i % locations.length],
      'date': DateTime.now().subtract(Duration(days: i)).toIso8601String(),
      'severity': severities[i % severities.length],
      'resolved': i % 3 == 0 ? 1 : 0, // 1/3 data resolved
      'photo_path': null, // atau path foto jika ada
    });
  }
  
  final batch = db.batch();
  for (final data in sampleData) {
    batch.insert('crime_reports', data);
  }
  
  await batch.commit();
  print('✅ Berhasil insert $count sample data');
}

// Method untuk menghapus data sample
Future<void> deleteSampleData() async {
  final db = await CrimeDbHelper.instance.database;
  await db.delete('crime_reports', where: 'id LIKE ?', whereArgs: ['sample_%']);
  print('✅ Berhasil hapus sample data');
}



Future<List<CrimeReport>> getAllCrimes() async {
  final db = await CrimeDbHelper.instance.database;
  final List<Map<String, dynamic>> maps = await db.query(
    'crime_reports',
    orderBy: 'date DESC',
  );
  return maps.map((map) => CrimeReport.fromMap(map)).toList();
}

// Method untuk cek total data
Future<int> getTotalDataCount() async {
  final db = await CrimeDbHelper.instance.database;
  final count = Sqflite.firstIntValue(
    await db.rawQuery('SELECT COUNT(*) FROM crime_reports')
  );
  return count ?? 0;
}

  Future<int> fixInvalidPhotoPaths() async {
  final db = await _db;
  final rows = await db.query(
    'crime_reports',
    columns: ['id', 'photo_path'],
  );

  int fixed = 0;
  for (final r in rows) {
    final id = r['id'] as String;
    final pathString = r['photo_path'] as String?;

    if (pathString == null || pathString.trim().isEmpty) continue;

    // ✅ UPDATE: Handle multiple paths
    final paths = pathString.split('|');
    final validPaths = <String>[];
    
    for (final path in paths) {
      if (path.trim().isEmpty) continue;
      
      final isContentUri = path.startsWith('content://');
      final exists = !isContentUri && File(path).existsSync();
      
      if (exists) {
        validPaths.add(path);
      }
    }
    
    // Update database dengan paths yang valid
    final newPathString = validPaths.isNotEmpty ? validPaths.join('|') : null;
    
    if (newPathString != pathString) {
      await db.update(
        'crime_reports',
        {'photo_path': newPathString},
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
