import 'package:flutter/material.dart';

import '../../services/storage/session_loader.dart';
import '../../theme/app_colors.dart';

/// Calendario mensual tipo "racha" (Duolingo): un punto por cada sesión
/// hecha, un hueco marcado para los días que se saltó (desde la primera
/// sesión registrada hasta hoy), y tocar un día con sesión abre su
/// resumen. Sin librería externa — es solo una grilla de 7 columnas.
class ProgressCalendar extends StatefulWidget {
  const ProgressCalendar({
    super.key,
    required this.sessionsByDay,
    required this.firstTrackedDay,
    required this.onDaySelected,
  });

  /// Claves normalizadas a medianoche (sin hora) — ver `_normalize`.
  final Map<DateTime, List<SavedSession>> sessionsByDay;

  /// Fecha (normalizada) de la primera sesión registrada — antes de eso no
  /// se marcan días como "saltados", ya que el paciente ni siquiera había
  /// empezado.
  final DateTime? firstTrackedDay;

  final void Function(DateTime day, List<SavedSession> sessions) onDaySelected;

  @override
  State<ProgressCalendar> createState() => _ProgressCalendarState();
}

DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

class _ProgressCalendarState extends State<ProgressCalendar> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  static const _monthNames = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];
  static const _weekdayLabels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday; // 1=lunes
    final leadingBlanks = firstWeekday - 1;
    final today = _normalize(DateTime.now());
    final firstTracked = widget.firstTrackedDay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _changeMonth(-1),
            ),
            Text(
              '${_monthNames[_month.month - 1]} ${_month.year}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _changeMonth(1),
            ),
          ],
        ),
        Row(
          children: [
            for (final label in _weekdayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.darkGrey.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
          itemCount: leadingBlanks + daysInMonth,
          itemBuilder: (context, index) {
            if (index < leadingBlanks) return const SizedBox.shrink();
            final day = index - leadingBlanks + 1;
            final date = DateTime(_month.year, _month.month, day);
            final sessions = widget.sessionsByDay[date] ?? const [];
            final hasSession = sessions.isNotEmpty;
            final isTracked = firstTracked != null && !date.isBefore(firstTracked);
            final missed = !hasSession && isTracked && date.isBefore(today);
            return _DayCell(
              day: day,
              hasSession: hasSession,
              missed: missed,
              isToday: date == today,
              onTap: hasSession ? () => widget.onDaySelected(date, sessions) : null,
            );
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          children: [
            _LegendDot(color: AppColors.tealPrimary, label: 'Medición hecha'),
            _LegendDot(color: AppColors.danger.withValues(alpha: 0.5), label: 'Día salteado'),
          ],
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.hasSession,
    required this.missed,
    required this.isToday,
    required this.onTap,
  });

  final int day;
  final bool hasSession;
  final bool missed;
  final bool isToday;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;
    if (hasSession) {
      background = AppColors.tealPrimary;
      foreground = Colors.white;
    } else if (missed) {
      background = AppColors.danger.withValues(alpha: 0.12);
      foreground = AppColors.danger;
    } else {
      background = Colors.transparent;
      foreground = AppColors.darkGrey;
    }

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: isToday ? Border.all(color: AppColors.tealPrimary, width: 2) : null,
        ),
        alignment: Alignment.center,
        child: hasSession
            ? const Icon(Icons.check, color: Colors.white, size: 16)
            : Text(
                '$day',
                style: TextStyle(
                  color: foreground,
                  fontSize: 12,
                  fontWeight: missed ? FontWeight.bold : FontWeight.normal,
                ),
              ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
