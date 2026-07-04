import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/app_providers.dart';
import '../models/attendance.dart';
import '../theme/app_theme.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, String> _monthSummary = {};
  List<AttendanceRecord> _dayRecords = [];
  bool _loadingDay = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadMonth(_focusedDay);
    _loadDay(_selectedDay!);
  }

  Future<void> _loadMonth(DateTime month) async {
    final engine = context.read<AppState>().engine;
    final data = await engine.getCalendarMonth(month.year, month.month);
    setState(() {
      _monthSummary = {
        for (final d in data)
          DateTime.parse(d['date']): d['summary'] as String,
      };
    });
  }

  Future<void> _loadDay(DateTime day) async {
    setState(() => _loadingDay = true);
    final engine = context.read<AppState>().engine;
    final records = await engine.getDayAttendance(day);
    setState(() {
      _dayRecords = records;
      _loadingDay = false;
    });
  }

  Color _colorForSummary(String summary) {
    switch (summary) {
      case 'ALL_PRESENT':
        return StatusColors.safe;
      case 'HAS_ABSENT':
        return StatusColors.critical;
      case 'MIXED':
        return StatusColors.warning;
      case 'HOLIDAY':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: ListView(
        children: [
          TableCalendar(
            firstDay: DateTime(2020),
            lastDay: DateTime(2100),
            focusedDay: _focusedDay,
            selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
              _loadDay(selected);
            },
            onPageChanged: (focused) {
              _focusedDay = focused;
              _loadMonth(focused);
            },
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, _) => _dayCell(day),
              todayBuilder: (context, day, _) => _dayCell(day, isToday: true),
              selectedBuilder: (context, day, _) => _dayCell(day, isSelected: true),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _selectedDay == null ? '' : _selectedDay!.toIso8601String().split('T').first,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (_loadingDay) const Center(child: CircularProgressIndicator()),
          if (!_loadingDay && _dayRecords.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Text('No classes (holiday or no timetable).')),
          ..._dayRecords.map((r) {
            final periodDuration = context.read<AppState>().periodDurationMinutes;
            final periods = (r.units * 60 / periodDuration).round();
            final periodLabel = '$periods ${periods == 1 ? "Period" : "Periods"}';
            return ListTile(
              title: Text(r.subjectName ?? 'Subject #${r.subjectId}'),
              subtitle: Text('${r.startTime ?? ""} - ${r.endTime ?? ""}  •  $periodLabel'),
              trailing: DropdownButton<AttendanceStatus>(
                value: r.status,
                items: AttendanceStatus.values
                    .map((s) => DropdownMenuItem(value: s, child: Text(statusToString(s))))
                    .toList(),
                onChanged: (newStatus) async {
                  if (newStatus == null) return;
                  final engine = context.read<AppState>().engine;
                  await engine.overrideAttendance(r.id, newStatus);
                  _loadDay(_selectedDay!);
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _dayCell(DateTime day, {bool isToday = false, bool isSelected = false}) {
    final key = DateTime(day.year, day.month, day.day);
    final summary = _monthSummary[key];
    final color = summary != null ? _colorForSummary(summary) : null;
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
        border: isToday ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text('${day.day}', style: TextStyle(color: isSelected ? Colors.white : null)),
          if (color != null && !isSelected)
            Positioned(
              bottom: 2,
              child: Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
            ),
        ],
      ),
    );
  }
}
