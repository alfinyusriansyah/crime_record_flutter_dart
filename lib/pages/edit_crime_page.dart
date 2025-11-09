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

  // ✅ UPDATE: Multiple photos state
  final List<String> _existingPhotoPaths = []; // foto lama dari initial
  final List<String> _newPhotoPaths = [];      // foto baru yang dipilih
  final List<String> _removedPhotoPaths = [];  // foto lama yang dihapus
  
  final _picker = ImagePicker();
  final int _maxPhotos = 3;

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
    
    // ✅ UPDATE: Initialize existing photos
    if (c?.photoPaths != null) {
      _existingPhotoPaths.addAll(c!.photoPaths);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndPromptRepickIfMissing());
  }

  Future<void> _checkAndPromptRepickIfMissing() async {
    if (_existingPhotoPaths.isEmpty) return;
    
    final missingPhotos = <String>[];
    for (final path in _existingPhotoPaths) {
      final exists = await File(path).exists();
      if (!exists) {
        missingPhotos.add(path);
      }
    }
    
    if (missingPhotos.isNotEmpty && mounted) {
      _existingPhotoPaths.removeWhere((path) => missingPhotos.contains(path));
      
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Foto tidak ditemukan'),
          content: Text('${missingPhotos.length} foto lama tidak tersedia.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('OK')
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

  // ✅ UPDATE: Pick multiple photos dengan limit
  Future<void> _pickFromCamera() async {
    if (_getTotalPhotoCount() >= _maxPhotos) {
      _showMaxPhotoAlert();
      return;
    }
    
    final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (x == null) return;
    
    final savedPath = await _saveToAppDir(x.path);
    setState(() {
      _newPhotoPaths.add(savedPath);
    });
  }

  Future<void> _pickFromGallery() async {
    if (_getTotalPhotoCount() >= _maxPhotos) {
      _showMaxPhotoAlert();
      return;
    }
    
    final remainingSlots = _maxPhotos - _getTotalPhotoCount();
    final x = await _picker.pickImage(
      source: ImageSource.gallery, 
      imageQuality: 85,
    );
    if (x == null) return;
    
    final savedPath = await _saveToAppDir(x.path);
    setState(() {
      _newPhotoPaths.add(savedPath);
    });
  }

  void _showMaxPhotoAlert() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Batas Foto'),
        content: const Text('Maksimal 3 foto per laporan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  int _getTotalPhotoCount() {
    return _existingPhotoPaths.length + _newPhotoPaths.length;
  }

  List<String> _getAllPhotoPaths() {
    return [..._existingPhotoPaths, ..._newPhotoPaths];
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

    // ✅ UPDATE: Combine existing (non-removed) and new photos
    final finalPhotoPaths = <String>[
      ..._existingPhotoPaths.where((path) => !_removedPhotoPaths.contains(path)),
      ..._newPhotoPaths,
    ];

    // Hapus foto yang di-remove
    for (final removedPath in _removedPhotoPaths) {
      try {
        final file = File(removedPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }

    final result = widget.initial == null
        ? CrimeReport.create(
            title: _title,
            description: _desc,
            location: _loc,
            name: _name,
            date: _date,
            severity: _severity,
            photoPaths: finalPhotoPaths, // ✅ UPDATE: List of paths
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
            photoPaths: finalPhotoPaths, // ✅ UPDATE: List of paths
          );

    if (!mounted) return;
    Navigator.pop(context, result);
  }

  // ✅ UPDATE: Remove photo methods
  void _removeExistingPhoto(int index) {
    setState(() {
      final removedPath = _existingPhotoPaths[index];
      _existingPhotoPaths.removeAt(index);
      _removedPhotoPaths.add(removedPath);
    });
  }

  void _removeNewPhoto(int index) {
    setState(() {
      final removedPath = _newPhotoPaths[index];
      _newPhotoPaths.removeAt(index);
      // Hapus file fisik untuk foto baru yang belum disimpan
      try {
        final file = File(removedPath);
        if (file.existsSync()) {
          file.delete();
        }
      } catch (_) {}
    });
  }

  void _removeAllPhotos() {
    setState(() {
      // Pindahkan semua existing photos ke removed
      _removedPhotoPaths.addAll(_existingPhotoPaths);
      _existingPhotoPaths.clear();
      
      // Hapus file fisik untuk new photos
      for (final path in _newPhotoPaths) {
        try {
          final file = File(path);
          if (file.existsSync()) {
            file.delete();
          }
        } catch (_) {}
      }
      _newPhotoPaths.clear();
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
    final allPhotos = _getAllPhotoPaths();
    final totalPhotos = _getTotalPhotoCount();

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

                        // ✅ UPDATE: Multiple Photos Section
                        Card(
                          margin: const EdgeInsets.only(top: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Text('Foto (maks. 3)', style: Theme.of(context).textTheme.labelLarge),
                                    const Spacer(),
                                    Text(
                                      '$totalPhotos/3',
                                      style: TextStyle(
                                        color: totalPhotos >= _maxPhotos ? Colors.red : Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Photo Grid
                                if (allPhotos.isNotEmpty) ...[
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                      childAspectRatio: 1,
                                    ),
                                    itemCount: allPhotos.length,
                                    itemBuilder: (context, index) {
                                      final path = allPhotos[index];
                                      final isExisting = index < _existingPhotoPaths.length;
                                      
                                      return Stack(
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.grey.shade300),
                                            ),
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
                                          ),
                                          Positioned(
                                            top: 4,
                                            right: 4,
                                            child: GestureDetector(
                                              onTap: () {
                                                if (isExisting) {
                                                  _removeExistingPhoto(index);
                                                } else {
                                                  _removeNewPhoto(index - _existingPhotoPaths.length);
                                                }
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: const BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  size: 16,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                // Empty State
                                if (allPhotos.isEmpty)
                                  Container(
                                    height: 100,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.grey.shade100,
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.photo_library, size: 32, color: Colors.grey),
                                        SizedBox(height: 8),
                                        Text('Tidak ada foto'),
                                      ],
                                    ),
                                  ),

                                const SizedBox(height: 12),

                                // Action Buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: totalPhotos >= _maxPhotos ? null : _pickFromCamera,
                                        icon: const Icon(Icons.photo_camera),
                                        label: const Text('Kamera'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: totalPhotos >= _maxPhotos ? null : _pickFromGallery,
                                        icon: const Icon(Icons.photo_library),
                                        label: const Text('Galeri'),
                                      ),
                                    ),
                                  ],
                                ),

                                if (allPhotos.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: _removeAllPhotos,
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Hapus Semua Foto'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
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