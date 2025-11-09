import 'package:flutter/material.dart';
import '../db/crime_sqlite_repository.dart';
import '../models/crime_report.dart';
import '../widgets/crime_tile.dart';
import 'edit_crime_page.dart';
import 'view_crime_page.dart';



class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final repo = CrimeSqliteRepository.instance;

  List<CrimeReport> items = [];
  bool loading = true;

  // 🔎 state filter
  String? _qName;
  DateTime? _fromDate;
  DateTime? _toDate;

  bool get _hasFilter =>
      (_qName?.isNotEmpty ?? false) || _fromDate != null || _toDate != null;

  Future<void> _clearFilters({bool doRefresh = true}) async {
    setState(() {
      _qName = null;
      _fromDate = null;
      _toDate = null;
    });
    if (doRefresh) await _refresh();
  }

Future<void> _printCrimeReports() async {
  final reports = await repo.search();
  for (final report in reports) {
    print('ID: ${report.id}, Path: ${report.photoPath}');
  }
}


@override
void initState() {
  super.initState();
  _runStartupFix();
   _printCrimeReports();
}

Future<void> _runStartupFix() async {
  try {
    await repo.fixInvalidPhotoPaths();
  } catch (_) {}
  _refresh();
}

  // @override
  // void initState() {
  //   super.initState();
  //   _refresh();
  // }

  Future<void> _refresh() async {
    setState(() => loading = true);
    final data = await repo.search(
      name: _qName,
      from: _fromDate,
      to: _toDate,
    );
    if (!mounted) return;
    setState(() {
      items = data;
      loading = false;
    });
  }

  Future<void> _add() async {
    final r = await Navigator.push<CrimeReport>(
      context,
      MaterialPageRoute(builder: (_) => const EditCrimePage()),
    );
    if (r != null) {
      await repo.create(r);
      await _refresh();
      _notify('Report created successfully'); // ✅ notifikasi
    }
  }

  void _notify(String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}

Future<T?> _showTopSheet<T>({
  required BuildContext context,
  required Widget child,
  Duration duration = const Duration(milliseconds: 300),
  bool dismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black54, // gelapkan background
    transitionDuration: duration,
    pageBuilder: (_, __, ___) {
      // Wajib return sesuatu, tapi UI kita dibangun di transitionBuilder.
      return const SizedBox.shrink();
    },
    transitionBuilder: (ctx, anim, __, ___) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -1), // dari atas
              end: Offset.zero,
            ).animate(curved),
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                constraints: const BoxConstraints(maxWidth: 700),
                width: MediaQuery.of(ctx).size.width,
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  // biar konten geser saat keyboard naik
                  bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
                  top: 12,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 12,
                      color: Colors.black26,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          ),
        ),
      );
    },
  );
}


// Future<void> _edit(CrimeReport c) async {
//   final r = await Navigator.push<CrimeReport>(
//     context,
//     MaterialPageRoute(builder: (_) => EditCrimePage(initial: c)),
//   );
//   if (r != null) {
//     await repo.update(r); // simpan ke DB
//     // ⬇️ update di memori — TANPA reload dari DB
//     final idx = items.indexWhere((e) => e.id == r.id);
//     if (idx != -1) {
//       setState(() {
//         items[idx] = r;
//       });
//     }
//   }
// }

  Future<void> _toggle(CrimeReport c) async {
    final upd = CrimeReport(
      id: c.id,
      name: c.name,
      title: c.title,
      description: c.description,
      location: c.location,
      date: c.date,
      severity: c.severity,
      resolved: !c.resolved,
      photoPath: c.photoPath
    );
    await repo.update(upd);
    await _refresh();
  }

  Future<void> _delete(CrimeReport c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete report?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await repo.delete(c.id);
      await _refresh();
      _notify('Report deleted'); // ✅ notifikasi
    }
  }

  Future<void> _openFilterSheetTop() async {
  final nameController = TextEditingController(text: _qName ?? '');
  DateTime? tempFrom = _fromDate;
  DateTime? tempTo   = _toDate;

  await _showTopSheet<void>(
    context: context,
    child: StatefulBuilder( // supaya tombol tanggal bisa setState lokal
      builder: (ctx, setLocal) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // “handle” kecil biar keliatan sheet
            Container(
              width: 42, height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Filter',
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.search,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(tempFrom == null
                        ? 'From'
                        : _fmtDate(tempFrom)),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: tempFrom ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        tempFrom = DateTime(picked.year, picked.month, picked.day);
                        setLocal((){}); // refresh isi sheet
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event),
                    label: Text(tempTo == null
                        ? 'To'
                        : _fmtDate(tempTo)),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: tempTo ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        tempTo = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
                        setLocal((){});
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _clearFilters();
                    },
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Apply'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _qName = nameController.text.trim().isEmpty
                            ? null
                            : nameController.text.trim();
                        _fromDate = tempFrom;
                        _toDate = tempTo;
                      });
                      _refresh();
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}


  // ✅ nullable aman
  static String _fmtDate(DateTime? d) {
    if (d == null) return '-';
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final filters = <Widget>[];

    if (_qName != null && _qName!.isNotEmpty) {
      filters.add(_FilterChip(
        label: 'Name: $_qName',
        onClear: () => setState(() => _qName = null),
      ));
    }
    if (_fromDate != null) {
      filters.add(_FilterChip(
        label: 'From: ${_fmtDate(_fromDate)}',
        onClear: () => setState(() => _fromDate = null),
      ));
    }
    if (_toDate != null) {
      filters.add(_FilterChip(
        label: 'To: ${_fmtDate(_toDate)}',
        onClear: () => setState(() => _toDate = null),
      ));
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, c) {
            return Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Results: ${items.length}',
                        style: theme.textTheme.titleMedium,
                      ),
                      if (_hasFilter) ...[
                        const SizedBox(width: 8),
                        ...filters,
                        TextButton.icon(
                          onPressed: () { _clearFilters(); },
                          icon: const Icon(Icons.clear_all, size: 18),
                          label: const Text('Clear all'),
                        ),
                      ] else
                        TextButton.icon(
                          onPressed: () { _openFilterSheetTop(); },
                          icon: const Icon(Icons.filter_alt),
                          label: const Text('Filter'),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Search / Filter',
                  onPressed: () { _openFilterSheetTop(); },
                  icon: const Icon(Icons.search),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () { _clearFilters(); }, // harus dibungkus closure
                  icon: const Icon(Icons.refresh),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 56),
            const SizedBox(height: 12),
            Text(
              _hasFilter ? 'No reports match your filters.' : 'No reports yet.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_hasFilter)
              OutlinedButton.icon(
                onPressed: () { _clearFilters(); },
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear filters'),
              )
            else
              FilledButton.icon(
                onPressed: () { _add(); },
                icon: const Icon(Icons.add),
                label: const Text('Add report'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_hasFilter) {
          await _clearFilters();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Crime Reporting App'),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () => _clearFilters(),
                child: LayoutBuilder(
                  builder: (_, cons) {
                    final maxWidth = cons.maxWidth > 700 ? 700.0 : cons.maxWidth;
                    return CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: maxWidth),
                              child: _buildHeader(context),
                            ),
                          ),
                        ),
                        if (items.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _buildEmptyState(context),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 80),
                            sliver: SliverList.separated(
                              itemCount: items.length,
                              itemBuilder: (_, i) => Center(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: maxWidth),
                                  child: CrimeTile(
                                    data: items[i],
                                        onTap: () async {
                                          final result = await Navigator.push<Object?>(
                                            context,
                                            MaterialPageRoute(builder: (_) => ViewCrimePage(item: items[i])),
                                          );

                                          if (result is CrimeReport) {
                                            // EDIT → patch item di memori (tanpa reload DB)
                                            final idx = items.indexWhere((e) => e.id == result.id);
                                            if (idx != -1) {
                                              setState(() => items[idx] = result);
                                            }
                                            _notify('Report updated');
                                          } else if (result == true) {
                                            // DELETE → refresh dari DB
                                            await _refresh();
                                            _notify('Report deleted');
                                          }
                                        },
                                    onDelete: () => _delete(items[i]),
                                    onToggleResolved: () => _toggle(items[i]),
                                  ),
                                ),
                              ),
                              separatorBuilder: (_, __) => const SizedBox(height: 6),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () { _add(); }, // harus dibungkus closure
          icon: const Icon(Icons.add),
          label: const Text('Add'),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.onClear});
  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      deleteIcon: const Icon(Icons.close, size: 18),
      onDeleted: onClear,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
