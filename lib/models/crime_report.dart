import 'package:uuid/uuid.dart';

class CrimeReport {
  final String id;
  String title;
  String description;
  String location;
  String name;
  DateTime date;
  String severity; // low | medium | high
  bool resolved;
  String? photoPath; // Bisa null

  CrimeReport({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.name,
    required this.date,
    required this.severity,
    this.resolved = false,
    this.photoPath, // Bisa null
  });

  factory CrimeReport.create({
    required String title,
    required String description,
    required String location,
    required String name,
    required DateTime date,
    String severity = 'medium',
    String? photoPath, // Bisa null
  }) {
    return CrimeReport(
      id: const Uuid().v4(),
      title: title,
      description: description,
      location: location,
      name: name,
      date: date,
      severity: severity,
      resolved: false,
      photoPath: photoPath, // Bisa null
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'name': name,
        'location': location,
        'date': date.toIso8601String(),
        'severity': severity,
        'resolved': resolved ? 1 : 0,
        'photo_path': photoPath, // Bisa null
      };

  factory CrimeReport.fromMap(Map<String, dynamic> m) => CrimeReport(
        id: m['id'] as String,
        title: m['title'] as String,
        description: (m['description'] ?? '') as String,
        location: (m['location'] ?? '') as String,
        name: (m['name'] ?? '') as String,
        date: DateTime.parse(m['date'] as String),
        severity: (m['severity'] ?? 'medium') as String,
        resolved: (m['resolved'] ?? 0) == 1,
        photoPath: m['photo_path'] as String?, // Bisa null
      );

  CrimeReport copyWith({
    String? id,
    String? name,
    String? title,
    String? description,
    String? location,
    DateTime? date,
    String? severity,
    bool? resolved,
    String? photoPath, // Ubah ke String? untuk single path
  }) {
    return CrimeReport(
      id: id ?? this.id,
      name: name ?? this.name,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      date: date ?? this.date,
      severity: severity ?? this.severity,
      resolved: resolved ?? this.resolved,
      photoPath: photoPath ?? this.photoPath, // Gunakan photoPath langsung
    );
  }

  // Helper method untuk cek apakah ada foto
  bool get hasPhoto => photoPath != null && photoPath!.isNotEmpty;
}