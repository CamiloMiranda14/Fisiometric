import 'package:flutter/material.dart';

import '../../services/storage/session_loader.dart';
import '../../services/storage/session_storage_service.dart';
import '../../theme/app_colors.dart';
import 'session_detail_screen.dart';
import 'widgets/session_list_tile.dart';

class SessionsListScreen extends StatefulWidget {
  const SessionsListScreen({super.key});

  @override
  State<SessionsListScreen> createState() => _SessionsListScreenState();
}

class _SessionsListScreenState extends State<SessionsListScreen> {
  final SessionStorageService _storage = SessionStorageService();
  late Future<List<SavedSession>> _future;

  @override
  void initState() {
    super.initState();
    _future = loadAllSessions(_storage);
  }

  Future<void> _refresh() async {
    final entries = await loadAllSessions(_storage);
    if (!mounted) return;
    setState(() => _future = Future.value(entries));
  }

  Future<void> _deleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar todas las sesiones?'),
        content: const Text(
          'Se borrarán todos los videos y datos guardados. Esta acción no '
          'se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar todo', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _storage.deleteAllSessions();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sesiones guardadas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Eliminar todas las sesiones',
            onPressed: _deleteAll,
          ),
        ],
      ),
      body: FutureBuilder<List<SavedSession>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data ?? const [];
          if (entries.isEmpty) {
            return RefreshIndicator(onRefresh: _refresh, child: const _EmptyState());
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return SessionListTile(
                  metadata: entry.metadata,
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SessionDetailScreen(
                          dir: entry.dir,
                          metadata: entry.metadata,
                        ),
                      ),
                    );
                    _refresh(); // por si se eliminó la sesión desde el detalle
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_open_outlined,
                    size: 64,
                    color: AppColors.tealPrimary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Todavía no hay sesiones guardadas',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
