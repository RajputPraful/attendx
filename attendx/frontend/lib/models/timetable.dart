class ClassSlot {
  final int id;
  final int timetableVersionId;
  final int subjectId;
  final int dayOfWeek; // 0=Mon..6=Sun
  final String startTime; // "HH:MM:SS"
  final String endTime;
  final double durationHours;

  ClassSlot({
    required this.id,
    required this.timetableVersionId,
    required this.subjectId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.durationHours,
  });

  factory ClassSlot.fromJson(Map<String, dynamic> json) => ClassSlot(
        id: json['id'],
        timetableVersionId: json['timetable_version_id'],
        subjectId: json['subject_id'],
        dayOfWeek: json['day_of_week'],
        startTime: json['start_time'],
        endTime: json['end_time'],
        durationHours: (json['duration_hours'] as num).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        if (id != 0) 'id': id,
        'timetable_version_id': timetableVersionId,
        'subject_id': subjectId,
        'day_of_week': dayOfWeek,
        'start_time': startTime,
        'end_time': endTime,
        'duration_hours': durationHours,
      };
}

class TimetableVersion {
  final int id;
  final String label;
  final String effectiveFrom; // "YYYY-MM-DD"
  final List<ClassSlot> slots;

  TimetableVersion({
    required this.id,
    required this.label,
    required this.effectiveFrom,
    required this.slots,
  });

  factory TimetableVersion.fromJson(Map<String, dynamic> json) => TimetableVersion(
        id: json['id'],
        label: json['label'],
        effectiveFrom: json['effective_from'],
        slots: (json['slots'] as List? ?? []).map((e) => ClassSlot.fromJson(e)).toList(),
      );

  Map<String, dynamic> toMap() => {
        if (id != 0) 'id': id,
        'label': label,
        'effective_from': effectiveFrom,
      };
}

const List<String> kWeekdayNames = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
];
