import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/crime_report.dart';
import 'dart:io';

class CrimeTile extends StatelessWidget {
  const CrimeTile({
    super.key,
    required this.data,
    required this.onTap,
    required this.onDelete,
    required this.onToggleResolved,
  });

  final CrimeReport data;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleResolved;

  Color _sevColor(String s) {
    switch (s) {
      case 'high': return Colors.red;
      case 'low': return Colors.green;
      default: return Colors.orange;
    }
  }

  String _capitalize(String s) =>
      s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEEE, dd-MM-yyyy', 'id_ID');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        onTap: onTap,

        // ✅ UPDATE: Thumbnail untuk multiple photos
        leading: SizedBox(
          width: 64,
          height: 64,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _buildPhotoThumbnail(),
          ),
        ),

        title: Text(
          data.name.isNotEmpty ? data.name : '-',
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              'Title: ${data.title}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    data.location.isNotEmpty ? data.location : '-',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today, size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _capitalize(df.format(data.date)),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
              ],
            ),
            // ✅ ADD: Photo count indicator
            if (data.hasPhotos) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.photo_library, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${data.photoCount} foto',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ],
        ),

        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: data.resolved ? 'Mark Unresolved' : 'Mark Resolved',
              icon: Icon(
                data.resolved ? Icons.check_circle : Icons.check_circle_outline,
                color: data.resolved ? Colors.green : null,
              ),
              onPressed: onToggleResolved,
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  // ✅ ADD: Method untuk build photo thumbnail
  Widget _buildPhotoThumbnail() {
    if (!data.hasPhotos) {
      return Container(
        width: 64,
        height: 64,
        color: Colors.grey.shade300,
        alignment: Alignment.center,
        child: Icon(
          data.resolved ? Icons.verified : Icons.warning_amber_rounded,
          color: _sevColor(data.severity),
        ),
      );
    }

    // Ambil foto pertama sebagai thumbnail
    final firstPhotoPath = data.photoPaths.first;
    final file = File(firstPhotoPath);
    
    if (!file.existsSync()) {
      return Container(
        color: Colors.grey.shade300,
        alignment: Alignment.center,
        child: const Icon(Icons.error, color: Colors.grey),
      );
    }

    return Stack(
      children: [
        Image.file(
          file,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
        ),
        // Overlay untuk menunjukkan jumlah foto
        if (data.photoCount > 1)
          Container(
            width: 64,
            height: 64,
            color: Colors.black54,
            alignment: Alignment.center,
            child: Text(
              '+${data.photoCount - 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}