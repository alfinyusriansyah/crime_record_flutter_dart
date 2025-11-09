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
    _checkImagePaths();  // ✅ UPDATE: check multiple photos
  }

  Future<void> _checkImagePaths() async {
    for (final path in data.photoPaths) {
      if (File(path).existsSync()) {
        print('Image path is valid: $path');
      } else {
        print('Image path is invalid or missing: $path');
      }
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
      Navigator.pop(context, updated);
    }
  }

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

    if (ok != true) return;

    // ✅ UPDATE: Delete semua foto yang terkait
    for (final photoPath in data.photoPaths) {
      try {
        final f = File(photoPath);
        if (await f.exists()) { 
          await f.delete(); 
        }
      } catch (_) { /* optional log */ }
    }

    await repo.delete(data.id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report deleted'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 1200),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 200));
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
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y-$m-$day $hh:$mm';
  }

  // ✅ ADD: Method untuk build photo gallery
  Widget _buildPhotoGallery() {
    if (data.photoPaths.isEmpty) {
      return const SizedBox.shrink();
    }

    final validPhotos = data.photoPaths.where((path) {
      final isFilePath = !path.startsWith('content://') && !path.startsWith('http');
      return isFilePath && File(path).existsSync();
    }).toList();

    if (validPhotos.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('No photos available'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Photos (${validPhotos.length})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: validPhotos.length,
          itemBuilder: (context, index) {
            final path = validPhotos[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => _FullscreenImage(path: path)),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.error),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
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
                        Expanded(
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
                                  if (data.photoPaths.isNotEmpty) 
                                    Chip(
                                      label: Text('${data.photoPaths.length} photos'),
                                      backgroundColor: Colors.blue.withOpacity(0.1),
                                      side: BorderSide(color: Colors.blue.withOpacity(0.3)),
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
                
                // ✅ UPDATE: Photo gallery section
                if (data.photoPaths.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildPhotoGallery(),
                    ),
                  ),
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