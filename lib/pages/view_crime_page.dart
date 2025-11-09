import 'package:flutter/material.dart';
import '../db/crime_sqlite_repository.dart';
import '../models/crime_report.dart';
import 'edit_crime_page.dart';
import 'dart:io';

class ViewCrimePage extends StatefulWidget {
  const ViewCrimePage({super.key, required this.item});
  final CrimeReport item;

  @override
  State<ViewCrimePage> createState() => _ViewCrimePageState();
}

class _ViewCrimePageState extends State<ViewCrimePage> {
  final repo = CrimeSqliteRepository.instance;
  late CrimeReport data;

  @override
  void initState() {
    super.initState();
    data = widget.item;
    _checkImagePath();  
  }

  Future<void> _checkImagePath() async {
    final path = data.photoPath;
    if (path != null && File(path).existsSync()) {
      print('Image path is valid: $path');
    } else {
      print('Image path is invalid or missing');
    }
  }

 Future<void> _edit() async {
  final updated = await Navigator.push<CrimeReport>(
    context,
    MaterialPageRoute(builder: (_) => EditCrimePage(initial: data)),
  );

  if (updated != null) {
    await repo.update(updated);
    if (!mounted) return;
    setState(() => data = updated);
    // 🔥 beri sinyal ke halaman sebelumnya (HomePage)
    Navigator.pop(context, updated);
  }
}

  // void _notify(String msg) {
  //   if (!mounted) return;
  //   final messenger = ScaffoldMessenger.of(context);
  //   messenger.removeCurrentSnackBar();
  //   messenger.showSnackBar(
  //     SnackBar(
  //       content: Text(msg),
  //       behavior: SnackBarBehavior.floating,
  //       duration: const Duration(milliseconds: 1600),
  //     ),
  //   );
  // }
  

  Future<void> _delete() async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Delete report?'),
      content: const Text('This action cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
      ],
    ),
  );

  // batal? stop di sini
  if (ok != true) return;

  // hapus foto (kalau ada)
  try {
    final path = data.photoPath;
    if (path != null) {
      final f = File(path);
      if (await f.exists()) { await f.delete(); }
    }
  } catch (_) { /* optional log */ }

  // hapus record di DB (sekali saja)
  await repo.delete(data.id);

  if (!mounted) return;

  // (opsional) beri notif singkat di halaman ini
  ScaffoldMessenger.of(context).removeCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Report deleted'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(milliseconds: 1200),
    ),
  );

  // beri sedikit waktu agar snackbar sempat muncul (opsional)
  await Future.delayed(const Duration(milliseconds: 200));

  // balik ke HomePage dengan sinyal "hapus sukses"
  Navigator.pop(context, true);
  }

  Color _sevColor(String s, BuildContext ctx) {
    switch (s) {
      case 'high':   return Colors.red;
      case 'low':    return Colors.green;
      default:       return Theme.of(ctx).colorScheme.tertiary;
    }
  }

  static String _fmtDate(DateTime? d) {
    if (d == null) return '-';
    // yyyy-mm-dd HH:mm
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y-$m-$day $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxWidth = 720.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crime Detail'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                // Header card
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: _sevColor(data.severity, context).withOpacity(0.15),
                          child: Icon(Icons.report, color: _sevColor(data.severity, context)),
                        ),
                        const SizedBox(width: 12),
                        Expanded( // ✅ sekarang valid, parent-nya Row
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText(
                                data.title,
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Chip(
                                    label: Text('Severity: ${data.severity.toUpperCase()}'),
                                    backgroundColor: _sevColor(data.severity, context).withOpacity(0.1),
                                    side: BorderSide(color: _sevColor(data.severity, context).withOpacity(0.3)),
                                  ),
                                  Chip(
                                    label: Text(data.resolved ? 'Resolved' : 'Unresolved'),
                                    backgroundColor: (data.resolved ? Colors.green : Colors.orange).withOpacity(0.1),
                                    side: BorderSide(color: (data.resolved ? Colors.green : Colors.orange).withOpacity(0.3)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Details card
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _DetailRow(icon: Icons.person, label: 'Nama Tersangka', value: data.name),
                        const Divider(height: 20),
                        _DetailRow(icon: Icons.location_on, label: 'Lokasi', value: data.location),
                        const Divider(height: 20),
                        _DetailRow(icon: Icons.today, label: 'Date', value: _fmtDate(data.date)),
                        const Divider(height: 20),
                        _DetailMultiline(icon: Icons.description, label: 'Deskripsi', value: data.description),
                      ],
                    ),
                  ),
                ),
                  if (data.photoPath != null && data.photoPath!.isNotEmpty) ...[
                    Builder(
                      builder: (ctx) {
                        final path = data.photoPath!;
                        // Pastikan ini path file lokal (bukan content://)
                        final isFilePath = !path.startsWith('content://') && !path.startsWith('http');
                        final file = File(path);

                        // Cek existence secara synchronous (lebih sederhana)
                        final exists = isFilePath && file.existsSync();

                        if (!exists) {
                          // fallback tampilan kalau file tidak ada
                          return Container(
                            height: 220,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Theme.of(ctx).colorScheme.surfaceVariant.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('Image unavailable'),
                          );
                        }

                        // Render aman + errorBuilder supaya tidak crash bila decode gagal
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => _FullscreenImage(path: path)),
                              );
                            },
                            child: Image.file(
                              file,
                              fit: BoxFit.cover,
                              height: 220,
                              width: double.infinity,
                              errorBuilder: (_, __, ___) => Container(
                                height: 220,
                                alignment: Alignment.center,
                                color: Theme.of(ctx).colorScheme.surfaceVariant.withOpacity(0.5),
                                child: const Text('Image error'),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _edit,
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: t.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: t.textTheme.labelMedium?.copyWith(color: t.colorScheme.outline)),
              const SizedBox(height: 4),
              SelectableText(value.isEmpty ? '-' : value, style: t.textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailMultiline extends StatelessWidget {
  const _DetailMultiline({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: t.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: t.textTheme.labelMedium?.copyWith(color: t.colorScheme.outline)),
              const SizedBox(height: 4),
              SelectableText(value.isEmpty ? '-' : value, style: t.textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }
}

class _FullscreenImage extends StatelessWidget {
  const _FullscreenImage({required this.path});
  final String path;

  @override 
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.file(File(path), fit: BoxFit.contain),
        ),
      ),
    );
  }
}
