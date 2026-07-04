enum AttendanceStatus { present, absent, noClass }

AttendanceStatus statusFromString(String s) {
  switch (s) {
    case 'PRESENT':
      return AttendanceStatus.present;
    case 'ABSENT':
      return AttendanceStatus.absent;
    default:
      return AttendanceStatus.noClass;
  }
}

String statusToString(AttendanceStatus s) {
  switch (s) {
    case AttendanceStatus.present:
      return 'PRESENT';
    case AttendanceStatus.absent:
      return 'ABSENT';
    case AttendanceStatus.noClass:
      return 'NO_CLASS';
  }
}

class AttendanceRecord {
  final int id;
  final int classSlotId;
  final String date;
  final AttendanceStatus status;
  final double units;
  final bool autoMarked;
  final int? subjectId;
  final String? subjectName;
  final String? startTime;
  final String? endTime;

  AttendanceRecord({
    required this.id,
    required this.classSlotId,
    required this.date,
    required this.status,
    required this.units,
    required this.autoMarked,
    this.subjectId,
    this.subjectName,
    this.startTime,
    this.endTime,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) => AttendanceRecord(
        id: json['id'],
        classSlotId: json['class_slot_id'],
        date: json['date'],
        status: statusFromString(json['status']),
        units: (json['units'] as num).toDouble(),
        autoMarked: json['auto_marked'] == 1 || json['auto_marked'] == true,
        subjectId: json['subject_id'],
        subjectName: json['subject_name'],
        startTime: json['start_time'],
        endTime: json['end_time'],
      );

  Map<String, dynamic> toMap() => {
        if (id != 0) 'id': id,
        'class_slot_id': classSlotId,
        'date': date,
        'status': statusToString(status),
        'units': units,
        'auto_marked': autoMarked ? 1 : 0,
      };
}
