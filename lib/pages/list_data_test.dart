import 'package:flutter/material.dart';
import 'dart:io';
import '../models/crime_report.dart';
import '../db/crime_sqlite_repository.dart';

class CrimeListPage extends StatefulWidget {
  const CrimeListPage({super.key});

  @override
  State<CrimeListPage> createState() => _CrimeListPageState();
}

class _CrimeListPageState extends State<CrimeListPage> {
  List<CrimeReport> _crimes = [];
  bool _isLoading = true;
  String _filter = 'all'; // all, resolved, unresolved
  String _sortBy = 'date'; // date, name, severity

  @override
  void initState() {
    super.initState();
    _loadCrimes();
  }

  Future<void> _loadCrimes() async {
    setState(() => _isLoading = true);
    
    try {
      final crimes = await CrimeSqliteRepository.instance.getAllCrimes();
      
      // Apply filter
      List<CrimeReport> filtered = crimes;
      if (_filter == 'resolved') {
        filtered = crimes.where((c) => c.resolved).toList();
      } else if (_filter == 'unresolved') {
        filtered = crimes.where((c) => !c.resolved).toList();
      }
      
      // Apply sorting
      filtered.sort((a, b) {
        switch (_sortBy) {
          case 'name':
            return a.name.compareTo(b.name);
          case 'severity':
            final severityOrder = {'high': 3, 'medium': 2, 'low': 1};
            return (severityOrder[b.severity] ?? 0).compareTo(severityOrder[a.severity] ?? 0);
          case 'date':
          default:
            return b.date.compareTo(a.date); // newest first
        }
      });
      
      setState(() => _crimes = filtered);
    } catch (e) {
      print('Error loading crimes: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'high': return Colors.red;
      case 'medium': return Colors.orange;
      case 'low': return Colors.green;
      default: return Colors.grey;
    }
  }

  IconData _getSeverityIcon(String severity) {
    switch (severity) {
      case 'high': return Icons.warning;
      case 'medium': return Icons.warning_amber;
      case 'low': return Icons.info;
      default: return Icons.help;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildCrimeCard(CrimeReport crime) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getSeverityColor(crime.severity),
          child: Icon(_getSeverityIcon(crime.severity), color: Colors.white, size: 20),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              crime.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Oleh: ${crime.name}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              crime.description.isNotEmpty 
                  ? crime.description 
                  : '(Tidak ada deskripsi)',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  crime.location,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatDate(crime.date),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            if (crime.resolved)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'SELESAI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        onTap: () {
          // Bisa navigasi ke detail page di sini
          _showCrimeDetails(crime);
        },
      ),
    );
  }

  void _showCrimeDetails(CrimeReport crime) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(crime.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Nama Tersangka', crime.name),
              _buildDetailRow('Deskripsi', crime.description.isNotEmpty ? crime.description : '(Tidak ada deskripsi)'),
              _buildDetailRow('Lokasi', crime.location),
              _buildDetailRow('Tanggal', _formatDate(crime.date)),
              _buildDetailRow('Tingkat Keparahan', crime.severity.toUpperCase()),
              _buildDetailRow('Status', crime.resolved ? 'SELESAI' : 'BELUM SELESAI'),
              if (crime.hasPhoto) ...[
                const SizedBox(height: 16),
                const Text('Foto:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: FileImage(File(crime.photoPath!)),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('TUTUP'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Laporan Kriminal'),
        actions: [
          IconButton(
            onPressed: _loadCrimes,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter & Sort Controls
          Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.filter_list, size: 16),
                      const SizedBox(width: 8),
                      const Text('Filter:'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _filter,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('Semua')),
                            DropdownMenuItem(value: 'resolved', child: Text('Selesai')),
                            DropdownMenuItem(value: 'unresolved', child: Text('Belum Selesai')),
                          ],
                          onChanged: (value) {
                            setState(() => _filter = value!);
                            _loadCrimes();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.sort, size: 16),
                      const SizedBox(width: 8),
                      const Text('Urutkan:'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _sortBy,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'date', child: Text('Tanggal (Terbaru)')),
                            DropdownMenuItem(value: 'name', child: Text('Nama Tersangka')),
                            DropdownMenuItem(value: 'severity', child: Text('Tingkat Keparahan')),
                          ],
                          onChanged: (value) {
                            setState(() => _sortBy = value!);
                            _loadCrimes();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Data Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Data: ${_crimes.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (_isLoading)
                  const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Crime List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _crimes.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('Tidak ada data laporan'),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadCrimes,
                        child: ListView.builder(
                          itemCount: _crimes.length,
                          itemBuilder: (context, index) => _buildCrimeCard(_crimes[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}