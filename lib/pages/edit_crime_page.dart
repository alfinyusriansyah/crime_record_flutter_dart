import 'package:flutter/material.dart';
import '../models/crime_report.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class EditCrimePage extends StatefulWidget {
  const EditCrimePage({super.key, this.initial});
  final CrimeReport? initial;

  @override
  State<EditCrimePage> createState() => _EditCrimePageState();
}

class _EditCrimePageState extends State<EditCrimePage> {
  final _form = GlobalKey<FormState>();
  late String _title, _desc, _loc, _name, _severity;
  late DateTime _date;

  // Foto
  String? _photoPath;          // foto lama (dari initial)    
  String? _tempImagePath;       // foto sementara (belum disimpan)
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _title     = c?.title ?? '';
    _desc      = c?.description ?? '';
    _loc       = c?.location ?? '';
    _name      = c?.name ?? '';
    _severity  = c?.severity ?? 'medium';
    _date      = c?.date ?? DateTime.now();
    _photoPath = c?.photoPath;   // foto lama (jika ada)
    _tempImagePath = null;       // preview baru (jika user pilih)

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndPromptRepickIfMissing());
  }

  Future<void> _checkAndPromptRepickIfMissing() async {
    if (_photoPath == null) return;
    final ok = await File(_photoPath!).exists();
    if (!ok && mounted) {
      _photoPath = null; // buang referensi lama
      // prompt re-pick
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Foto tidak ditemukan'),
          content: const Text('File foto lama tidak tersedia. Pilih foto baru?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Nanti')),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _pickFromGallery();
              },
              child: const Text('Pilih Sekarang'),
            ),
          ],
        ),
      );
    }
  }

  Future<String> _saveToAppDir(String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'crime_${DateTime.now().millisecondsSinceEpoch}${p.extension(sourcePath)}';
    final dest = p.join(dir.path, fileName);
    final nf = await File(sourcePath).copy(dest);
    return nf.path;
  }

  Future<void> _pickFromCamera() async {
    final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (x == null) return;
    setState(() {
      _tempImagePath = x.path;   // hanya preview
    });
  }

  Future<void> _pickFromGallery() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x == null) return;
    setState(() {
      _tempImagePath = x.path;   // hanya preview
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (t == null) return;
    setState(() => _date = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  void _save() async {
    if (!_form.currentState!.validate()) return;
    _form.currentState!.save();

    String? finalPhotoPath = _photoPath;

    if (_tempImagePath != null) {
      // Hapus file lama jika ada
      if (_photoPath != null) {
        try {
          final f = File(_photoPath!);
          if (await f.exists()) { 
            await f.delete(); 
          }
        } catch (_) {}
      }
      // Salin foto baru ke app dir
      finalPhotoPath = await _saveToAppDir(_tempImagePath!);
    }

    final result = widget.initial == null
        ? CrimeReport.create(
            title: _title,
            description: _desc,
            location: _loc,
            name: _name,
            date: _date,
            severity: _severity,
            photoPath: finalPhotoPath, // TIDAK pakai !, biarkan null
          )
        : CrimeReport(
            id: widget.initial!.id,
            title: _title,
            description: _desc,
            location: _loc,
            name: _name,
            date: _date,
            severity: _severity,
            resolved: widget.initial!.resolved,
            photoPath: finalPhotoPath, // TIDAK pakai !, biarkan null
          );

    if (!mounted) return;
    Navigator.pop(context, result);
  }

  void _removePhoto() {
    setState(() {
      _tempImagePath = null;
      _photoPath = null;
    });
  }

  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon) : null,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Crime' : 'Add Crime'),
        actions: [
          IconButton(
            onPressed: _save,
            tooltip: 'Save',
            icon: const Icon(Icons.save),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth > 600 ? 600.0 : constraints.maxWidth;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          initialValue: _name,
                          decoration: _inputDecoration('Nama Tersangka', icon: Icons.person),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama tersangka harus diisi' : null,
                          onSaved: (v) => _name = v!.trim(),
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          initialValue: _title,
                          decoration: _inputDecoration('Nama Kasus', icon: Icons.title),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama kasus harus diisi' : null,
                          onSaved: (v) => _title = v!.trim(),
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          initialValue: _desc,
                          maxLines: 3,
                          decoration: _inputDecoration('Deskripsi', icon: Icons.description),
                          onSaved: (v) => _desc = v ?? '',
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          initialValue: _loc,
                          decoration: _inputDecoration('Lokasi', icon: Icons.location_on),
                          onSaved: (v) => _loc = v ?? '',
                        ),
                        const SizedBox(height: 14),

                        DropdownButtonFormField<String>(
                          value: _severity,
                          decoration: _inputDecoration('Tingkat Keparahan', icon: Icons.warning_amber),
                          items: const [
                            DropdownMenuItem(value: 'low', child: Text('Rendah')),
                            DropdownMenuItem(value: 'medium', child: Text('Sedang')),
                            DropdownMenuItem(value: 'high', child: Text('Tinggi')),
                          ],
                          onChanged: (v) => setState(() => _severity = v ?? 'medium'),
                        ),

                        const SizedBox(height: 14),

                        // ===== Foto Section =====
                        Card(
                          margin: const EdgeInsets.only(top: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('Foto (opsional)', style: Theme.of(context).textTheme.labelLarge),
                                const SizedBox(height: 8),

                                AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Builder(
                                      builder: (_) {
                                        final pathToShow = _tempImagePath ?? _photoPath;
                                        if (pathToShow == null) {
                                          return Container(
                                            alignment: Alignment.center,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surfaceVariant
                                                .withOpacity(0.5),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.photo, size: 48, color: Colors.grey[600]),
                                                const SizedBox(height: 8),
                                                const Text('Tidak ada foto'),
                                              ],
                                            ),
                                          );
                                        }
                                        return GestureDetector(
                                          onTap: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => _FullscreenImage(path: pathToShow),
                                              ),
                                            );
                                          },
                                          child: Image.file(
                                            File(pathToShow),
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceVariant
                                                  .withOpacity(0.5),
                                              alignment: Alignment.center,
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.error_outline, size: 48, color: Colors.grey[600]),
                                                  const SizedBox(height: 8),
                                                  const Text('Gagal memuat gambar'),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _pickFromCamera,
                                        icon: const Icon(Icons.photo_camera),
                                        label: const Text('Kamera'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _pickFromGallery,
                                        icon: const Icon(Icons.photo_library),
                                        label: const Text('Galeri'),
                                      ),
                                    ),
                                  ],
                                ),

                                if (_tempImagePath != null || _photoPath != null) ...[
                                  const SizedBox(height: 4),
                                  TextButton.icon(
                                    onPressed: _removePhoto,
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Hapus Foto'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          title: const Text('Tanggal & Waktu'),
                          subtitle: Text(
                            '${_date.toLocal()}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                          trailing: FilledButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: const Text('Ubah'),
                          ),
                        ),

                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.save),
                          label: const Text('Simpan Laporan'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
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