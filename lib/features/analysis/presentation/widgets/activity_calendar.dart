import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../data/analysis_api.dart';
import '../../data/models.dart';

const _weekdayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _shortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _weekdayFullNames = [
  'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
];

String _pad2(int n) => n.toString().padLeft(2, '0');
String _isoDate(int year, int month, int day) => '$year-${_pad2(month)}-${_pad2(day)}';

String _formatDuration(int? seconds) {
  if (seconds == null) return '—';
  final mins = (seconds / 60).round();
  if (mins < 60) return '$mins min';
  return '${mins ~/ 60}h ${mins % 60}m';
}

String _formatTime(DateTime d) {
  final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final period = d.hour < 12 ? 'AM' : 'PM';
  return '$hour12:${_pad2(d.minute)} $period';
}

/// Monthly activity calendar: a filled dot marks a day with a logged
/// workout, an outlined dot marks no workout — a rest day is a normal
/// outcome, never styled as an error. Tapping a day opens a bottom sheet
/// with what was logged, or "No workout logged." Cells are sized for a
/// comfortable thumb tap (44dp+), and the 7-column grid never overflows
/// horizontally on narrow phones.
class ActivityCalendar extends ConsumerStatefulWidget {
  const ActivityCalendar({super.key});

  @override
  ConsumerState<ActivityCalendar> createState() => _ActivityCalendarState();
}

class _ActivityCalendarState extends ConsumerState<ActivityCalendar> {
  late int _year;
  late int _month;
  Future<List<CalendarDay>>? _future;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _load();
  }

  void _load() {
    _future = ref.read(analysisApiProvider).fetchActivityCalendar(year: _year, month: _month);
  }

  void _goPrev() {
    setState(() {
      if (_month == 1) {
        _month = 12;
        _year -= 1;
      } else {
        _month -= 1;
      }
      _load();
    });
  }

  void _goNext() {
    final now = DateTime.now();
    if (_year == now.year && _month == now.month) return;
    setState(() {
      if (_month == 12) {
        _month = 1;
        _year += 1;
      } else {
        _month += 1;
      }
      _load();
    });
  }

  void _openDay(String dateStr, CalendarDay? day) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _DayDetailSheet(dateStr: dateStr, day: day),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth = _year == now.year && _month == now.month;
    final todayIso = _isoDate(now.year, now.month, now.day);

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _goPrev,
                icon: const Icon(Icons.chevron_left_rounded),
                color: context.colors.inkSecondary,
                iconSize: 22,
              ),
              Text(
                '${_months[_month - 1]} $_year',
                style: TextStyle(color: context.colors.ink, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              IconButton(
                onPressed: isCurrentMonth ? null : _goNext,
                icon: const Icon(Icons.chevron_right_rounded),
                color: context.colors.inkSecondary,
                disabledColor: context.colors.inkMuted.withValues(alpha: 0.3),
                iconSize: 22,
              ),
            ],
          ),
          FutureBuilder<List<CalendarDay>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('Couldn\'t load the calendar.',
                        style: TextStyle(color: context.colors.inkMuted, fontSize: 12)),
                  ),
                );
              }
              final byDate = {for (final d in snapshot.data ?? const <CalendarDay>[]) d.date: d};
              final firstWeekday = DateTime(_year, _month, 1).weekday % 7; // Sun=0
              final daysInMonth = DateTime(_year, _month + 1, 0).day;

              return Column(
                children: [
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (final label in _weekdayLabels)
                        Expanded(
                          child: Center(
                            child: Text(label, style: TextStyle(color: context.colors.inkMuted, fontSize: 11)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: firstWeekday + daysInMonth,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                    ),
                    itemBuilder: (context, index) {
                      if (index < firstWeekday) return const SizedBox.shrink();
                      final day = index - firstWeekday + 1;
                      final dateStr = _isoDate(_year, _month, day);
                      final entry = byDate[dateStr];
                      final hasWorkout = entry != null;
                      final isFuture = dateStr.compareTo(todayIso) > 0;
                      final isToday = dateStr == todayIso;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: isFuture ? null : () => _openDay(dateStr, entry),
                          borderRadius: BorderRadius.circular(8),
                          child: Opacity(
                            opacity: isFuture ? 0.3 : 1,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$day',
                                  style: TextStyle(
                                    color: isToday ? context.colors.accent : context.colors.inkSecondary,
                                    fontSize: 12,
                                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: hasWorkout ? context.colors.accent : Colors.transparent,
                                    border: hasWorkout ? null : Border.all(color: context.colors.line, width: 1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DayDetailSheet extends StatelessWidget {
  final String dateStr;
  final CalendarDay? day;

  const _DayDetailSheet({required this.dateStr, required this.day});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(dateStr);
    final label = '${_weekdayFullNames[date.weekday % 7]}, ${_shortMonths[date.month - 1]} ${date.day}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: context.colors.line, borderRadius: BorderRadius.circular(2)),
            ),
            Text(label, style: TextStyle(color: context.colors.ink, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            if (day == null || day!.workouts.isEmpty)
              Text('No workout logged.', style: TextStyle(color: context.colors.inkMuted, fontSize: 13))
            else
              for (final w in day!.workouts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(w.name,
                            style: TextStyle(color: context.colors.ink, fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatTime(w.performedAt)} · ${w.exerciseCount} '
                          '${w.exerciseCount == 1 ? 'exercise' : 'exercises'} · ${w.setCount} '
                          '${w.setCount == 1 ? 'set' : 'sets'}',
                          style: TextStyle(color: context.colors.inkMuted, fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${w.totalVolumeKg.round()} kg volume · ${_formatDuration(w.durationSeconds)}',
                          style: TextStyle(color: context.colors.inkSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
