import 'package:flutter/material.dart';
import '../db/crime_sqlite_repository.dart';
import '../models/crime_report.dart';
import '../widgets/crime_tile.dart';
import 'edit_crime_page.dart';
import 'view_crime_page.dart';
import '../pages/test_large_data_page.dart';

enum _NoticeType { success, info, warning, error }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final repo = CrimeSqliteRepository.instance;

  // 🎯 PAGINATION STATE
  final List<CrimeReport> _items = [];
  final int _pageSize = 30; // Data per page
  int _currentPage = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _isInitialLoading = true;
  final _scrollController = ScrollController();

  // 🔎 Filter state
  String? _qName;
  DateTime? _fromDate;
  DateTime? _toDate;

  bool get _hasFilter =>
      (_qName?.isNotEmpty ?? false) || _fromDate != null || _toDate != null;

  @override
  void initState() {
    super.initState();
    _runStartupFix();
    _setupScrollListener();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreData();
      }
    });
  }

  Future<void> _runStartupFix() async {
    try {
      await repo.fixInvalidPhotoPaths();
    } catch (_) {}
    _loadInitialData();
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
      _notify('Report deleted', type: _NoticeType.warning);
    }
  }

  Future<void> _add() async {
    final r = await Navigator.push<CrimeReport>(
      context,
      MaterialPageRoute(builder: (_) => const EditCrimePage()),
    );
    if (r != null) {
      await repo.create(r);
      await _refresh();
      _notify('Report created successfully', type: _NoticeType.success);
    }
  }

  // 🎯 LOAD DATA DENGAN PAGINATION
  Future<void> _loadInitialData() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _isInitialLoading = true;
      _currentPage = 0;
      _hasMore = true;
    });

    try {
      final crimes = await repo.getCrimesPaginated(
        limit: _pageSize,
        offset: 0,
        name: _qName,
        from: _fromDate,
        to: _toDate,
      );

      if (!mounted) return;
      
      setState(() {
        _items.clear();
        _items.addAll(crimes);
        _hasMore = crimes.length == _pageSize;
        _currentPage = 1;
      });
    } catch (e) {
      print('Error loading initial data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoading || !_hasMore) return;
    
    setState(() => _isLoading = true);

    try {
      final crimes = await repo.getCrimesPaginated(
        limit: _pageSize,
        offset: _currentPage * _pageSize,
        name: _qName,
        from: _fromDate,
        to: _toDate,
      );

      if (!mounted) return;
      
      setState(() {
        _items.addAll(crimes);
        _hasMore = crimes.length == _pageSize;
        _currentPage++;
      });
    } catch (e) {
      print('Error loading more data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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

  Future<void> _clearFilters({bool doRefresh = true}) async {
    setState(() {
      _qName = null;
      _fromDate = null;
      _toDate = null;
    });
    if (doRefresh) await _loadInitialData();
  }

  Future<void> _refresh() async {
    await _loadInitialData();
  }

  // 🎯 TAMPILKAN LOADING INDICATOR
  Widget _buildLoadingIndicator() {
    if (!_hasMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No more data',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  void _notify(
    String message, {
    _NoticeType type = _NoticeType.info,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final cs = Theme.of(context).colorScheme;

    // Tentukan warna & ikon per tipe
    late final Color bg;
    late final IconData icon;
    switch (type) {
      case _NoticeType.success:
        bg = cs.primaryContainer;
        icon = Icons.check_circle_rounded;
        break;
      case _NoticeType.info:
        bg = cs.surfaceContainerHighest;
        icon = Icons.info_rounded;
        break;
      case _NoticeType.warning:
        bg = Colors.orange.shade700;
        icon = Icons.warning_amber_rounded;
        break;
      case _NoticeType.error:
        bg = Colors.red.shade700;
        icon = Icons.error_rounded;
        break;
    }

    final snack = SnackBar(
      content: Row(
        children: [
          Icon(icon, color: cs.onPrimaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      elevation: 8,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      duration: const Duration(milliseconds: 1600),
      action: (actionLabel != null && onAction != null)
          ? SnackBarAction(
              label: actionLabel,
              onPressed: onAction,
              textColor: cs.primary,
            )
          : null,
    );

    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(snack);
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

  // HANYA UPDATE method yang berkaitan dengan filter & refresh
  Future<void> _openFilterSheetTop() async {
    final nameController = TextEditingController(text: _qName ?? '');
    DateTime? tempFrom = _fromDate;
    DateTime? tempTo   = _toDate;

    await _showTopSheet<void>(
      context: context,
      child: StatefulBuilder(
        builder: (ctx, setLocal) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ... (UI filter TETAP SAMA) ...
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
                          setLocal((){});
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
                        _loadInitialData(); // ✅ Gunakan loadInitial, bukan refresh
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

  static String _fmtDate(DateTime? d) {
    if (d == null) return '-';
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  // 🎯 UPDATE HEADER DENGAN TOTAL COUNT
  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final filters = <Widget>[];

    if (_qName != null && _qName!.isNotEmpty) {
      filters.add(_FilterChip(
        label: 'Name: $_qName',
        onClear: () {
          setState(() => _qName = null);
          _loadInitialData();
        },
      ));
    }
    if (_fromDate != null) {
      filters.add(_FilterChip(
        label: 'From: ${_fmtDate(_fromDate)}',
        onClear: () {
          setState(() => _fromDate = null);
          _loadInitialData();
        },
      ));
    }
    if (_toDate != null) {
      filters.add(_FilterChip(
        label: 'To: ${_fmtDate(_toDate)}',
        onClear: () {
          setState(() => _toDate = null);
          _loadInitialData();
        },
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
                      FutureBuilder<int>(
                        future: repo.getCrimesCount(
                          name: _qName,
                          from: _fromDate,
                          to: _toDate,
                        ),
                        builder: (context, snapshot) {
                          final total = snapshot.data ?? 0;
                          return Text(
                            'Results: ${_items.length} of $total',
                            style: theme.textTheme.titleMedium,
                          );
                        },
                      ),
                      if (_hasFilter) ...[
                        const SizedBox(width: 8),
                        ...filters,
                        TextButton.icon(
                          onPressed: () { _clearFilters(); },
                          icon: const Icon(Icons.clear_all, size: 18),
                          label: const Text('Clear all'),
                        ),
                      ] 
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
                  onPressed: () { _clearFilters(); },
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => const TestDataPage(),
                    ));
                  },
                  icon: const Icon(Icons.data_usage),
                  tooltip: 'Test Data',
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
      body: _isInitialLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInitialData,
              child: LayoutBuilder(
                builder: (_, cons) {
                  final maxWidth = cons.maxWidth > 700 ? 700.0 : cons.maxWidth;
                  return CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      // ✅ ALTERNATIF: SliverAppBar untuk sticky header
                      SliverAppBar(
                        pinned: true,
                        floating: false,
                        collapsedHeight: 80,
                        expandedHeight: 80,
                        toolbarHeight: 80,
                        automaticallyImplyLeading: false, // Hilangkan back button
                        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                        elevation: 1,
                        shadowColor: Colors.black12,
                        flexibleSpace: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxWidth),
                            child: _buildHeader(context),
                          ),
                        ),
                      ),
                      
                      // ... sisa sliver content sama seperti sebelumnya
                      if (_items.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildEmptyState(context),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 80),
                          sliver: SliverList.separated(
                            itemCount: _items.length + (_hasMore ? 1 : 0),
                            itemBuilder: (_, i) {
                              if (i >= _items.length) {
                                return Center(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: maxWidth),
                                    child: _buildLoadingIndicator(),
                                  ),
                                );
                              }
                              
                              return Center(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: maxWidth),
                                  child: CrimeTile(
                                    data: _items[i],
                                    onTap: () async {
                                      final result = await Navigator.push<Object?>(
                                        context,
                                        MaterialPageRoute(builder: (_) => ViewCrimePage(item: _items[i])),
                                      );

                                      if (result is CrimeReport) {
                                        final idx = _items.indexWhere((e) => e.id == result.id);
                                        if (idx != -1) {
                                          setState(() => _items[idx] = result);
                                        }
                                        _notify('Report updated', type: _NoticeType.success);
                                      } else if (result == true) {
                                        await _loadInitialData();
                                        _notify('Report deleted', type: _NoticeType.warning);
                                      }
                                    },
                                    onDelete: () => _delete(_items[i]),
                                    onToggleResolved: () => _toggle(_items[i]),
                                  ),
                                ),
                              );
                            },
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
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