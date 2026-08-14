import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/session_metadata.dart';
import '../../services/storage/session_storage_service.dart';
import '../../theme/app_colors.dart';
import 'session_detail_screen.dart';
import 'widgets/session_list_tile.dart';

class SessionsListScreen extends StatefulWidget {
  const SessionsListScreen({super.key});

  @override
  State<SessionsListScreen> createState() => _SessionsListScreenState();
}

class _SessionEntry {
  const _SessionEntry({required this.dir, required this.metadata});

  final Directory dir;
  final SessionMetadata metadata;
}

class _SessionsListScreenState extends State<SessionsListScreen> {
  final SessionStorageService _storage = SessionStorageService();
  late Future<List<_SessionEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_SessionEntry>> _load() async {
    final dirs = await _storage.listSessionDirectories();
    final entries = <_SessionEntry>[];
    for (final dir in dirs) {
      final jsonFile = File('${dir.path}/session.json');
      if (!await jsonFile.exists()) continue;
      try {
        final raw = jsonDecode(await jsonFile.readAsString()) as Map<String, dynamic>;
        entries.add(_SessionEntry(dir: dir, metadata: SessionMetadata.fromJson(raw)));
      } catch (_) {
        // session.json corrupto o incompleto (p.ej. la app se cerró a mitad
        // de guardar) — se omite en vez de romper toda la lista.
        continue;
      }
    }
    return entries;
  }

  Future<void> _refresh() async {
    final entries = await _load();
    if (!mounted) return;
    setState(() => _future = Future.value(entries));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sesiones guardadas')),
      body: FutureBuilder<List<_SessionEntry>>(
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
