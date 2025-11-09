import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/crime_report.dart';
import '../db/crime_sqlite_repository.dart';

class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  final CrimeSqliteRepository _repo = CrimeSqliteRepository.instance;

  Future<String?> exportToExcelWithPhotos() async {
    try {
      print('🔄 Starting export process...');
      
      // Get all data
      final crimes = await _repo.all();
      print('📊 Found ${crimes.length} crime reports');
      
      // Create export directory - konsisten menggunakan approach yang sama
      final exportDir = await getApplicationDocumentsDirectory();
      final exportFolder = Directory('${exportDir.path}/CrimeReports_Export');
      
      if (!await exportFolder.exists()) {
        await exportFolder.create(recursive: true);
      }
      
      // Create photos subdirectory
      final photosDir = Directory('${exportFolder.path}/gambar');
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }
      
      // Copy photos
      final photoMapping = await _copyPhotosToExport(exportFolder, crimes);
      print('🖼️ Copied ${photoMapping.length} photos');
      
      // Create Excel file
      final excelFile = await _createExcelFile(exportFolder, crimes, photoMapping);
      print('📄 Excel file created: ${excelFile.path}');
      
      // Share using share_plus (no permission needed)
      await Share.shareXFiles(
        [XFile(excelFile.path)],
        subject: 'Data Laporan Kriminal',
        text: 'Export data laporan kriminal ${DateTime.now().toString()}',
      );
      
      return excelFile.path;
    } catch (e) {
      print('❌ Export error: $e');
      rethrow;
    }
  }

  Future<Map<String, String>> _copyPhotosToExport(
      Directory exportDir, List<CrimeReport> crimes) async {
    final photosDir = Directory('${exportDir.path}/gambar');
    final photoMapping = <String, String>{};
    int photoCounter = 1;

    for (final crime in crimes) {
      for (final originalPath in crime.photoPaths) {
        try {
          final originalFile = File(originalPath);
          if (await originalFile.exists()) {
            final extension = _getFileExtension(originalPath);
            // Buat nama file yang lebih friendly
            final safeId = crime.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
            final newFileName = 'foto_${photoCounter}_$safeId$extension';
            final newPath = '${photosDir.path}/$newFileName';
            
            await originalFile.copy(newPath);
            photoMapping[originalPath] = newFileName;
            photoCounter++;
          }
        } catch (e) {
          print('Error copying photo $originalPath: $e');
        }
      }
    }

    return photoMapping;
  }

  String _getFileExtension(String path) {
    try {
      final ext = path.split('.').last.toLowerCase();
      return '.$ext';
    } catch (e) {
      return '.jpg'; // fallback extension
    }
  }

  Future<File> _createExcelFile(
      Directory exportDir,
      List<CrimeReport> crimes,
      Map<String, String> photoMapping) async {
    
    // Create Excel workbook
    final excel = Excel.createExcel();
    final sheet = excel['Laporan Kriminal'];

    // Add headers
    final headers = [
      'ID', 'Nama Tersangka', 'Nama Kasus', 'Deskripsi', 
      'Lokasi', 'Tanggal', 'Tingkat Keparahan', 'Status',
      'Jumlah Foto', 'Nama File Foto'
    ];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByString('${String.fromCharCode(65 + i)}1'));
      cell.value = headers[i];
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: '4472C4',
        fontColorHex: 'FFFFFF',
      );
    }

    // Add data rows
    for (int i = 0; i < crimes.length; i++) {
      final crime = crimes[i];
      final row = i + 2; // Start from row 2

      // Get photo info for this crime
      final crimePhotos = crime.photoPaths
          .map((path) => photoMapping[path] ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

      // Set cell values dengan TextCellValue
      sheet.cell(CellIndex.indexByString('A$row')).value = crime.id;
      sheet.cell(CellIndex.indexByString('B$row')).value = crime.name;
      sheet.cell(CellIndex.indexByString('C$row')).value = crime.title;
      sheet.cell(CellIndex.indexByString('D$row')).value = crime.description;
      sheet.cell(CellIndex.indexByString('E$row')).value = crime.location;
      sheet.cell(CellIndex.indexByString('F$row')).value = _formatDateForExcel(crime.date);
      sheet.cell(CellIndex.indexByString('G$row')).value = _translateSeverity(crime.severity);
      sheet.cell(CellIndex.indexByString('H$row')).value = crime.resolved ? 'Selesai' : 'Belum Selesai';
      sheet.cell(CellIndex.indexByString('I$row')).value = crime.photoPaths.length.toString();
      sheet.cell(CellIndex.indexByString('J$row')).value = crimePhotos.join(', ');

      // Style for resolved status
      if (crime.resolved) {
        final statusCell = sheet.cell(CellIndex.indexByString('H$row'));
        statusCell.cellStyle = CellStyle(
          backgroundColorHex: 'C6EFCE',
          fontColorHex: '006100',
        );
      }

      // Alternate row colors for readability
      if (i % 2 == 1) {
        for (int col = 0; col < headers.length; col++) {
          final cell = sheet.cell(CellIndex.indexByString('${String.fromCharCode(65 + col)}$row'));
          cell.cellStyle = CellStyle(backgroundColorHex: 'F2F2F2');
        }
      }
    }

    // Auto-adjust column widths
    _autoAdjustColumns(sheet, headers.length);

    // Save Excel file
    final excelBytes = excel.save()!;
    final excelFile = File('${exportDir.path}/data_laporan_kriminal.xlsx');
    await excelFile.writeAsBytes(excelBytes);

    return excelFile;
  }

  String _formatDateForExcel(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _translateSeverity(String severity) {
    switch (severity) {
      case 'low': return 'Rendah';
      case 'medium': return 'Sedang';
      case 'high': return 'Tinggi';
      default: return severity;
    }
  }

  void _autoAdjustColumns(Sheet sheet, int columnCount) {
    // Manual column width setting
    final columnWidths = {
      'A': 30.0, // ID
      'B': 20.0, // Nama Tersangka
      'C': 25.0, // Nama Kasus
      'D': 40.0, // Deskripsi
      'E': 25.0, // Lokasi
      'F': 20.0, // Tanggal
      'G': 15.0, // Tingkat Keparahan
      'H': 15.0, // Status
      'I': 15.0, // Jumlah Foto
      'J': 50.0, // Nama File Foto
    };

    // Apply column widths menggunakan index numerik
    for (final entry in columnWidths.entries) {
      try {
        final columnLetter = entry.key;
        final colIndex = columnLetter.codeUnitAt(0) - 'A'.codeUnitAt(0);
        sheet.setColumnWidth(colIndex, entry.value);
      } catch (e) {
        print('Error setting column width for ${entry.key}: $e');
      }
    }
  }

  // Method untuk get export directory info - diperbarui
  Future<Map<String, dynamic>> getExportInfo() async {
    try {
      final exportDir = await getApplicationDocumentsDirectory();
      final exportFolder = Directory('${exportDir.path}/CrimeReports_Export');
      final excelFile = File('${exportFolder.path}/data_laporan_kriminal.xlsx');
      final photosDir = Directory('${exportFolder.path}/gambar');
      
      final excelExists = await excelFile.exists();
      
      int photoCount = 0;
      if (await photosDir.exists()) {
        final photoFiles = await photosDir.list().toList();
        photoCount = photoFiles.where((entity) => entity is File).length;
      }

      return {
        'exportPath': exportFolder.path,
        'excelExists': excelExists,
        'photoCount': photoCount,
        'excelFile': excelFile,
        'photosDir': photosDir,
      };
    } catch (e) {
      print('Error getting export info: $e');
      return {
        'exportPath': '',
        'excelExists': false,
        'photoCount': 0,
        'excelFile': null,
        'photosDir': null,
      };
    }
  }

  // Method tambahan untuk cleanup export files
  Future<void> cleanupExportFiles() async {
    try {
      final exportDir = await getApplicationDocumentsDirectory();
      final exportFolder = Directory('${exportDir.path}/CrimeReports_Export');
      
      if (await exportFolder.exists()) {
        await exportFolder.delete(recursive: true);
        print('✅ Export files cleaned up');
      }
    } catch (e) {
      print('Error cleaning up export files: $e');
    }
  }

  // Method untuk share semua file (Excel + Photos)
  Future<void> shareAllExportedFiles() async {
    try {
      final exportInfo = await getExportInfo();
      final files = <XFile>[];
      
      // Add Excel file
      if (exportInfo['excelExists'] == true) {
        files.add(XFile(exportInfo['excelFile'].path));
      }
      
      // Add photos
      if (exportInfo['photoCount'] > 0 && exportInfo['photosDir'] != null) {
        final photosDir = exportInfo['photosDir'] as Directory;
        final photoFiles = await photosDir.list().toList();
        for (final entity in photoFiles) {
          if (entity is File) {
            files.add(XFile(entity.path));
          }
        }
      }
      
      if (files.isNotEmpty) {
        await Share.shareXFiles(
          files,
          subject: 'Data Laporan Kriminal Lengkap',
          text: 'Export lengkap data laporan kriminal beserta foto-foto terkait. ${DateTime.now().toString()}',
        );
      }
    } catch (e) {
      print('Error sharing all files: $e');
      rethrow;
    }
  }
}