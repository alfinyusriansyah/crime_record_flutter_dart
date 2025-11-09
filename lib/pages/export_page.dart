import 'package:flutter/material.dart';
import '../services/export_service.dart';

class ExportPage extends StatefulWidget {
  const ExportPage({super.key});

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  final ExportService _exportService = ExportService();
  bool _isExporting = false;
  String _exportStatus = '';
  Map<String, dynamic>? _exportInfo;

  @override
  void initState() {
    super.initState();
    _loadExportInfo();
  }

  Future<void> _loadExportInfo() async {
    final info = await _exportService.getExportInfo();
    setState(() => _exportInfo = info);
  }

  Future<void> _exportData() async {
    setState(() {
      _isExporting = true;
      _exportStatus = 'Mempersiapkan data...';
    });

    try {
      setState(() => _exportStatus = 'Mengumpulkan data laporan...');
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() => _exportStatus = 'Menyalin foto ke folder export...');
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() => _exportStatus = 'Membuat file Excel...');
      
      final exportPath = await _exportService.exportToExcelWithPhotos();

      setState(() {
        _isExporting = false;
        _exportStatus = 'Export berhasil!';
      });

      if (exportPath != null) {
        _showSuccessDialog(exportPath);
      }

      // Refresh export info
      await _loadExportInfo();
      
    } catch (e) {
      setState(() {
        _isExporting = false;
        _exportStatus = 'Error: $e';
      });
      
      _showErrorDialog(e.toString());
    }
  }

  void _showSuccessDialog(String exportPath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Export Berhasil'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Data berhasil diexport ke:'),
            const SizedBox(height: 8),
            Text(
              exportPath,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (_exportInfo != null) ...[
              _buildInfoRow('File Excel', 'data_laporan_kriminal.xlsx'),
              _buildInfoRow('Jumlah Foto', '${_exportInfo!['photoCount']} file'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Export Gagal'),
          ],
        ),
        content: Text('Terjadi error: $error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Data'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.import_export, size: 48, color: Colors.blue),
                    const SizedBox(height: 16),
                    const Text(
                      'Export Data ke Excel',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Export semua data laporan kriminal ke file Excel beserta foto-foto yang terkait.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    
                    if (_exportInfo != null) ...[
                      const Divider(),
                      const SizedBox(height: 8),
                      _buildInfoRow('Lokasi Export', _exportInfo!['exportPath']),
                      _buildInfoRow('File Excel', _exportInfo!['excelExists'] ? 'Ada' : 'Belum ada'),
                      _buildInfoRow('Foto tersimpan', '${_exportInfo!['photoCount']} file'),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Export Button
            if (_isExporting) ...[
              Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _exportStatus,
                    style: const TextStyle(color: Colors.blue),
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            ]
            else
              FilledButton.icon(
                onPressed: _exportData,
                icon: const Icon(Icons.file_download),
                label: const Text('EXPORT KE EXCEL'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

            const SizedBox(height: 16),
            

            // Status
            if (_exportStatus.isNotEmpty && !_isExporting)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_exportStatus)),
                  ],
                ),
              ),

            const Spacer(),

            // Info
            const Card(
              color: Color(0xFFF0F0F0),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informasi Export:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('• File Excel: data_laporan_kriminal.xlsx'),
                    Text('• Foto: disimpan di folder /gambar'),
                    Text('• Lokasi: Folder Download/CrimeReports'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}