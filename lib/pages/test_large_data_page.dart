import 'package:flutter/material.dart';
import '../db/crime_sqlite_repository.dart';
import '../pages/list_data_test.dart';

class TestDataPage extends StatelessWidget {
  const TestDataPage({super.key});

  Future<void> _insert100Data(BuildContext context) async {
    final scaffold = ScaffoldMessenger.of(context);
    
    try {
      scaffold.showSnackBar(
        const SnackBar(content: Text('Memulai insert 100 data...'))
      );
      
      await CrimeSqliteRepository.instance.insertSampleData(100);
      
      final total = await CrimeSqliteRepository.instance.getTotalDataCount();
      
      scaffold.showSnackBar(
        SnackBar(
          content: Text('✅ Berhasil! Total data: $total'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        )
      );
    } catch (e) {
      scaffold.showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        )
      );
    }
  }

  Future<void> _deleteAllData(BuildContext context) async {
    final scaffold = ScaffoldMessenger.of(context);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Semua Data?'),
        content: const Text('Tindakan ini akan menghapus SEMUA data crime report. Lanjutkan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('BATAL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('HAPUS SEMUA', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await CrimeSqliteRepository.instance.deleteSampleData();
        scaffold.showSnackBar(
          const SnackBar(
            content: Text('✅ Semua data berhasil dihapus'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          )
        );
      } catch (e) {
        scaffold.showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          )
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Data'),
        backgroundColor: Colors.orange,
      ),
      body: SafeArea(
        child: SingleChildScrollView( // ✅ PERBAIKAN: Tambahkan scroll
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card Insert Data
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(Icons.data_usage, size: 48, color: Colors.blue),
                      const SizedBox(height: 16),
                      const Text(
                        'Generate Sample Data',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Akan menambahkan 100 data sample untuk testing performa dan fitur',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => _insert100Data(context),
                        icon: const Icon(Icons.add_chart),
                        label: const Text('INSERT 100 DATA SAMPLE'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.blue,
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Card Info & Actions
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      FutureBuilder<int>(
                        future: CrimeSqliteRepository.instance.getTotalDataCount(),
                        builder: (context, snapshot) {
                          final total = snapshot.data ?? 0;
                          return Column(
                            children: [
                              const Icon(Icons.storage, size: 48, color: Colors.green),
                              const SizedBox(height: 8),
                              Text(
                                'Total Data: $total',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sample Data: ${_countSampleData(total)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // ✅ PERBAIKAN: Gunakan Column dengan constraints untuk tombol
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 400;
                          
                          if (isWide) {
                            // Layout horizontal untuk layar lebar
                            return Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _deleteAllData(context),
                                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                                    label: const Text('Hapus Semua', style: TextStyle(color: Colors.red)),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(50),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final total = await CrimeSqliteRepository.instance.getTotalDataCount();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Total data: $total'),
                                          duration: const Duration(seconds: 2),
                                        )
                                      );
                                    },
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Refresh Count'),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(50),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          } else {
                            // Layout vertikal untuk layar sempit
                            return Column(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _deleteAllData(context),
                                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                                  label: const Text('Hapus Semua Data', style: TextStyle(color: Colors.red)),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(50),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final total = await CrimeSqliteRepository.instance.getTotalDataCount();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Total data: $total'),
                                        duration: const Duration(seconds: 2),
                                      )
                                    );
                                  },
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Refresh Data Count'),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(50),
                                  ),
                                ),
                              ],
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Card View Data
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(Icons.list_alt, size: 48, color: Colors.purple),
                      const SizedBox(height: 16),
                      const Text(
                        'Lihat Semua Data',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Lihat dan kelola semua data crime report yang tersimpan',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => const CrimeListPage(),
                          ));
                        },
                        icon: const Icon(Icons.view_list),
                        label: const Text('LIHAT SEMUA DATA'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.purple,
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Card Quick Actions
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(Icons.speed, size: 48, color: Colors.orange),
                      const SizedBox(height: 16),
                      const Text(
                        'Quick Actions',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Aksi cepat untuk testing dan development',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () => _insert100Data(context),
                            icon: const Icon(Icons.add),
                            label: const Text('100 Data'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () => CrimeSqliteRepository.instance.insertSampleData(10),
                            icon: const Icon(Icons.add),
                            label: const Text('10 Data'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () async {
                              final total = await CrimeSqliteRepository.instance.getTotalDataCount();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Total: $total data'))
                              );
                            },
                            icon: const Icon(Icons.info),
                            label: const Text('Info'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method untuk menghitung sample data
  String _countSampleData(int total) {
    // Asumsi sample data memiliki ID yang diawali 'sample_'
    // Di implementasi nyata, Anda perlu query database
    return '~${total ~/ 2}'; // Estimasi saja
  }
}