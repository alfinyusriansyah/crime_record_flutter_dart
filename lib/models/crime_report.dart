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
  List<String> photoPaths; // ✅ UBAH: List untuk multiple photos

  CrimeReport({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.name,
    required this.date,
    required this.severity,
    this.resolved = false,
    List<String>? photoPaths, // ✅ UBAH: List<String>?
  }) : photoPaths = photoPaths ?? []; // ✅ Default empty list

  factory CrimeReport.create({
    required String title,
    required String description,
    required String location,
    required String name,
    required DateTime date,
    String severity = 'medium',
    List<String>? photoPaths, // ✅ UBAH: List<String>?
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
      photoPaths: photoPaths, // ✅ UBAH: List photos
    );
  }

  // ✅ UPDATE: Convert List to comma-separated string for database
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'name': name,
        'location': location,
        'date': date.toIso8601String(),
        'severity': severity,
        'resolved': resolved ? 1 : 0,
        'photo_path': photoPaths.isEmpty ? null : photoPaths.join('|'), // ✅ SEPARATOR
      };

  // ✅ UPDATE: Convert comma-separated string back to List
  factory CrimeReport.fromMap(Map<String, dynamic> m) {
    final photoPathString = m['photo_path'] as String?;
    final List<String> paths = photoPathString?.split('|').where((path) => path.isNotEmpty).toList() ?? [];
    
    return CrimeReport(
      id: m['id'] as String,
      title: m['title'] as String,
      description: (m['description'] ?? '') as String,
      location: (m['location'] ?? '') as String,
      name: (m['name'] ?? '') as String,
      date: DateTime.parse(m['date'] as String),
      severity: (m['severity'] ?? 'medium') as String,
      resolved: (m['resolved'] ?? 0) == 1,
      photoPaths: paths, // ✅ UBAH: Convert to List
    );
  }

  CrimeReport copyWith({
    String? id,
    String? name,
    String? title,
    String? description,
    String? location,
    DateTime? date,
    String? severity,
    bool? resolved,
    List<String>? photoPaths, // ✅ UBAH: List<String>?
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
      photoPaths: photoPaths ?? this.photoPaths, // ✅ UBAH: List photos
    );
  }

  // ✅ UPDATE: Helper methods untuk multiple photos
  bool get hasPhotos => photoPaths.isNotEmpty;
  int get photoCount => photoPaths.length;
  bool get canAddMorePhotos => photoCount < 3;

  // ✅ ADD: Method untuk menambah foto dengan limit 3
  void addPhotoPath(String path) {
    if (photoPaths.length < 3) {
      photoPaths.add(path);
    }
  }

  // ✅ ADD: Method untuk menghapus foto
  void removePhotoPath(String path) {
    photoPaths.remove(path);
  }

  // ✅ ADD: Method untuk menghapus foto by index
  void removePhotoAt(int index) {
    if (index >= 0 && index < photoPaths.length) {
      photoPaths.removeAt(index);
    }
  }

  // ✅ ADD: Method untuk clear semua foto
  void clearAllPhotos() {
    photoPaths.clear();
  }
}