import 'package:flutter/material.dart';

import '../../services/storage/session_loader.dart';
import '../../theme/app_colors.dart';
import '../exercises/exercise_catalog.dart';
import '../sessions/session_detail_screen.dart';
import '../sessions/widgets/friendly_session_summary.dart';

/// Resumen amigable de todas las mediciones hechas un día específico —
/// se abre al tocar un día marcado en el calendario de [ProgressScreen].
/// Para el detalle técnico completo (video, gráfica cuadro a cuadro) se
/// entra a SessionDetailScreen desde cada tarjeta.
class DaySummaryScreen extends StatelessWidget {
  const DaySummaryScreen({super.key, required this.day, required this.sessions});

  final DateTime day;
  final List<SavedSession> sessions;

  static const _monthNames = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  @override
  Widget build(BuildContext context) {
    final dateLabel = '${day.day} de ${_monthNames[day.month - 1]} de ${day.year}';
    return Scaffold(
      appBar: AppBar(title: Text(dateLabel)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            sessions.length == 1
                ? 'Hiciste 1 medición ese día.'
                : 'Hiciste ${sessions.length} mediciones ese día.',
            style: TextStyle(color: AppColors.darkGrey.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 16),
          for (final session in sessions) ...[
            _DaySessionCard(session: session),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

class _DaySessionCard extends StatelessWidget {
  const _DaySessionCard({required this.session});

  final SavedSession session;

  @override
  Widget build(BuildContext context) {
    final metadata = session.metadata;
    final exercise = metadata.exerciseId == null ? null : exerciseForId(metadata.exerciseId!);
    String two(int n) => n.toString().padLeft(2, '0');
    final timeLabel = '${two(metadata.startedAt.hour)}:${two(metadata.startedAt.minute)}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lowConfidence.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.tealPrimary.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  exercise?.name ?? 'Medición',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Text(timeLabel, style: TextStyle(color: AppColors.darkGrey.withValues(alpha: 0.6))),
            ],
          ),
          const SizedBox(height: 12),
          FriendlySessionSummary(dir: session.dir, metadata: metadata),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.videocam_outlined, size: 18),
              label: const Text('Ver video y detalle completo'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SessionDetailScreen(dir: session.dir, metadata: metadata),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
