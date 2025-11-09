// import 'package:collection/collection.dart';
import '../models/crime_report.dart';

abstract class ICrimeRepository {
  Future<List<CrimeReport>> all();
  Future<CrimeReport> create(CrimeReport report);
  Future<void> update(CrimeReport report);
  Future<void> delete(String id);
}

class InMemoryCrimeRepository implements ICrimeRepository {
  final List<CrimeReport> _data = [];

  @override
  Future<List<CrimeReport>> all() async {
    // sort terbaru dulu
    _data.sort((a, b) => b.date.compareTo(a.date));
    return List.unmodifiable(_data);
  }

  @override
  Future<CrimeReport> create(CrimeReport report) async {
    _data.add(report);
    return report;
  }

  @override
  Future<void> update(CrimeReport report) async {
    final idx = _data.indexWhere((e) => e.id == report.id);
    if (idx >= 0) _data[idx] = report;
  }

  @override
  Future<void> delete(String id) async {
    _data.removeWhere((e) => e.id == id);
  }
}

// singleton sederhana
final crimeRepo = InMemoryCrimeRepository();
