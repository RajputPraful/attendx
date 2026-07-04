import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_providers.dart';
import '../models/timetable.dart';

/// Lets the user build a weekly timetable and save it as a new
/// TimetableVersion effective from a chosen date. Saturday is off by
/// default; toggling it on enables adding slots on Saturday.
class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  bool saturdayEnabled = false;
  DateTime effectiveFrom = DateTime.now();
  final Map<int, List<_DraftSlot>> slotsByDay = {for (var i = 0; i < 7; i++) i: []};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLatestTimetable();
  }

  Future<void> _loadLatestTimetable() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      setState(() => _isLoading = true);
      final db = context.read<AppState>().db;
      final versions = await db.getTimetableVersions();
      if (versions.isNotEmpty && mounted) {
        final latest = versions.first;
        final slots = await db.getSlotsForVersion(latest['id'] as int);
        
        setState(() {
          for (var i = 0; i < 7; i++) slotsByDay[i]!.clear();
          for (var slot in slots) {
            final day = slot['day_of_week'] as int;
            if (day == 5 || day == 6) {
              saturdayEnabled = true;
            }
            slotsByDay[day]!.add(_DraftSlot(
              slot['subject_id'] as int,
              slot['start_time'] as String,
              slot['end_time'] as String,
              (slot['duration_hours'] as num).toDouble(),
            ));
          }
        });
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  void _addSlot(int day) async {
    final app = context.read<AppState>();
    if (app.subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a subject first')),
      );
      return;
    }
    final slot = await showModalBottomSheet<_DraftSlot>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _SlotEditorSheet(existingSlots: slotsByDay[day]!),
    );
    if (slot != null) {
      setState(() => slotsByDay[day]!.add(slot));
    }
  }

  Future<void> _saveTimetable() async {
    final db = context.read<AppState>().db;
    final allSlots = <Map<String, dynamic>>[];
    slotsByDay.forEach((day, slots) {
      for (final s in slots) {
        allSlots.add({
          'subject_id': s.subjectId,
          'day_of_week': day,
          'start_time': s.startTime,
          'end_time': s.endTime,
          'duration_hours': s.durationHours,
        });
      }
    });
    
    final version = {
      'label': 'Timetable from ${effectiveFrom.toIso8601String().split("T").first}',
      'effective_from': effectiveFrom.toIso8601String().split("T").first,
    };

    try {
      await db.createTimetableVersion(version, allSlots);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Timetable saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving timetable: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final days = List.generate(saturdayEnabled ? 6 : 5, (i) => i); // Mon-Fri, +Sat if enabled

    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Timetable')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveTimetable,
        icon: const Icon(Icons.save),
        label: const Text('Save as new version'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable Saturday classes'),
                    value: saturdayEnabled,
                    onChanged: (v) => setState(() => saturdayEnabled = v),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Effective from'),
                    subtitle: Text(effectiveFrom.toIso8601String().split('T').first),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: effectiveFrom,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => effectiveFrom = picked);
                    },
                  ),
                  Text(
                    'Tip: creating a new version here does not erase your old timetable — '
                    'past dates keep using whichever version was active at the time.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...days.map((day) => _DayCard(
                day: day,
                slots: slotsByDay[day]!,
                subjectsLookup: {for (var s in app.subjects) s.id: s.name},
                onAdd: () => _addSlot(day),
                onRemove: (i) => setState(() => slotsByDay[day]!.removeAt(i)),
              )),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _DraftSlot {
  final int subjectId;
  final String startTime;
  final String endTime;
  final double durationHours;
  _DraftSlot(this.subjectId, this.startTime, this.endTime, this.durationHours);
}

class _DayCard extends StatelessWidget {
  final int day;
  final List<_DraftSlot> slots;
  final Map<int, String> subjectsLookup;
  final VoidCallback onAdd;
  final void Function(int) onRemove;

  const _DayCard({
    required this.day,
    required this.slots,
    required this.subjectsLookup,
    required this.onAdd,
    required this.onRemove,
  });

  String _formatTime(String timeWithSeconds) {
    final parts = timeWithSeconds.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return timeWithSeconds;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(kWeekdayNames[day], style: Theme.of(context).textTheme.titleMedium),
                IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: onAdd),
              ],
            ),
            if (slots.isEmpty) const Text('No classes'),
            ...slots.asMap().entries.map((e) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(subjectsLookup[e.value.subjectId] ?? 'Subject #${e.value.subjectId}'),
                  subtitle: Text('${_formatTime(e.value.startTime)} - ${_formatTime(e.value.endTime)}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => onRemove(e.key),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _SlotEditorSheet extends StatefulWidget {
  final List<_DraftSlot> existingSlots;
  const _SlotEditorSheet({required this.existingSlots});

  @override
  State<_SlotEditorSheet> createState() => _SlotEditorSheetState();
}

class _SlotEditorSheetState extends State<_SlotEditorSheet> {
  int? subjectId;
  TimeOfDay start = const TimeOfDay(hour: 9, minute: 0);
  int durationMinutes = 50;

  @override
  void initState() {
    super.initState();
    if (widget.existingSlots.isNotEmpty) {
      int maxEndMin = 0;
      for (final slot in widget.existingSlots) {
        final partsE = slot.endTime.split(':');
        if (partsE.length >= 2) {
          final eMin = int.parse(partsE[0]) * 60 + int.parse(partsE[1]);
          if (eMin > maxEndMin) {
            maxEndMin = eMin;
          }
        }
      }
      if (maxEndMin > 0) {
        start = TimeOfDay(hour: (maxEndMin ~/ 60) % 24, minute: maxEndMin % 60);
      }
    }
  }

  bool _hasConflict() {
    final newStartMin = start.hour * 60 + start.minute;
    final newEndMin = newStartMin + durationMinutes;

    for (final slot in widget.existingSlots) {
      final partsS = slot.startTime.split(':');
      final partsE = slot.endTime.split(':');
      if (partsS.length >= 2 && partsE.length >= 2) {
        final sMin = int.parse(partsS[0]) * 60 + int.parse(partsS[1]);
        final eMin = int.parse(partsE[0]) * 60 + int.parse(partsE[1]);
        if (newStartMin < eMin && newEndMin > sMin) {
          return true;
        }
      }
    }
    return false;
  }

  void _submit() {
    if (subjectId == null) return;
    if (_hasConflict()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This time slot overlaps with another class.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    Navigator.pop(context, _DraftSlot(subjectId!, _fmt(start), _fmt(end), durationHours));
  }

  String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  TimeOfDay get end {
    final startMin = start.hour * 60 + start.minute;
    final endMin = startMin + durationMinutes;
    return TimeOfDay(hour: (endMin ~/ 60) % 24, minute: endMin % 60);
  }

  double get durationHours => durationMinutes / 60.0;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add Class Slot', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: subjectId,
            decoration: const InputDecoration(labelText: 'Subject'),
            items: app.subjects.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
            onChanged: (v) => setState(() => subjectId = v),
          ),
          const SizedBox(height: 12),
          ListTile(
            title: const Text('Start time'),
            trailing: Text(_fmt(start)),
            onTap: () async {
              final t = await showTimePicker(context: context, initialTime: start);
              if (t != null) setState(() => start = t);
            },
          ),
          ListTile(
            title: const Text('Duration (minutes)'),
            trailing: SizedBox(
              width: 80,
              child: TextFormField(
                initialValue: durationMinutes.toString(),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.end,
                onChanged: (v) {
                  final parsed = int.tryParse(v);
                  if (parsed != null && parsed > 0) {
                    setState(() => durationMinutes = parsed);
                  }
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Builder(builder: (ctx) {
              final periodDuration = context.read<AppState>().periodDurationMinutes;
              final periods = durationMinutes / periodDuration;
              final periodsLabel = periods == periods.roundToDouble()
                  ? '${periods.toInt()} ${periods.toInt() == 1 ? "Period" : "Periods"}'
                  : '${periods.toStringAsFixed(1)} Periods';
              return Text(
                'End time: ${_fmt(end)}  •  $periodsLabel',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              );
            }),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: subjectId == null ? null : _submit,
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
