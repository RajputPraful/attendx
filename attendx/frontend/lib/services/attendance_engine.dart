import 'dart:math';
import 'local_db.dart';
import '../models/subject.dart';
import '../models/timetable.dart';
import '../models/attendance.dart';
import '../models/dashboard.dart';

class AttendanceEngine {
  final LocalDb db = LocalDb.instance;

  Future<Map<String, dynamic>?> getActiveTimetableVersion(DateTime date) async {
    final versions = await db.getTimetableVersions();
    final dStr = date.toIso8601String().split('T').first;
    for (var v in versions) {
      if ((v['effective_from'] as String).compareTo(dStr) <= 0) {
        return v;
      }
    }
    return null;
  }

  Future<bool> isHoliday(DateTime date) async {
    final weekday = date.weekday; // 1=Mon, 7=Sun
    if (weekday == 7) return true;
    if (weekday == 6) {
      final sem = await db.getSemester();
      if (sem != null && sem['saturday_enabled'] == 1) return false;
      return true;
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> getSlotsForDate(DateTime date) async {
    if (await isHoliday(date)) return [];
    final v = await getActiveTimetableVersion(date);
    if (v == null) return [];
    
    // In Dart DateTime, weekday is 1=Mon..7=Sun
    // In DB, day_of_week is 0=Mon..6=Sun
    final dbWeekday = date.weekday - 1;
    
    final database = await db.database;
    final slots = await database.query(
      'class_slots',
      where: 'timetable_version_id = ? AND day_of_week = ?',
      whereArgs: [v['id'], dbWeekday],
    );
    return slots;
  }

  Future<List<Map<String, dynamic>>> ensureAttendanceForDate(DateTime date) async {
    final dStr = date.toIso8601String().split('T').first;
    final slots = await getSlotsForDate(date);
    final created = <Map<String, dynamic>>[];
    final database = await db.database;

    for (var slot in slots) {
      final existing = await database.query(
        'attendance_records',
        where: 'class_slot_id = ? AND date = ?',
        whereArgs: [slot['id'], dStr],
      );
      
      if (existing.isEmpty) {
        final rec = {
          'class_slot_id': slot['id'],
          'date': dStr,
          'status': 'PRESENT',
          'units': slot['duration_hours'],
          'auto_marked': 1,
        };
        final id = await database.insert('attendance_records', rec);
        rec['id'] = id;
        created.add(rec);
      }
    }
    return created;
  }

  Future<void> autoMarkRange(DateTime start, DateTime end) async {
    var d = start;
    while (d.compareTo(end) <= 0) {
      await ensureAttendanceForDate(d);
      d = d.add(const Duration(days: 1));
    }
  }

  Future<Map<String, dynamic>> computeSubjectStats(Subject subject, {DateTime? upTo}) async {
    final database = await db.database;
    var query = '''
      SELECT a.* FROM attendance_records a
      JOIN class_slots c ON a.class_slot_id = c.id
      WHERE c.subject_id = ?
    ''';
    var args = <dynamic>[subject.id];

    if (upTo != null) {
      query += ' AND a.date <= ?';
      args.add(upTo.toIso8601String().split('T').first);
    }

    final records = await database.rawQuery(query, args);

    double totalClasses = 0;
    double attended = 0;

    for (var r in records) {
      final status = r['status'] as String;
      final units = (r['units'] as num).toDouble();
      if (status != 'NO_CLASS') {
        totalClasses += units;
        if (status == 'PRESENT') attended += units;
      }
    }

    final percentage = totalClasses > 0 ? (attended / totalClasses * 100) : 0.0;
    final reqFrac = subject.requiredPercentage / 100.0;
    
    int safeBunks = 0;
    if (reqFrac > 0) {
      safeBunks = ((attended / reqFrac) - totalClasses).floor();
    }
    safeBunks = percentage >= subject.requiredPercentage ? max(safeBunks, 0) : min(safeBunks, 0);

    String statusStr = 'CRITICAL';
    if (percentage >= subject.requiredPercentage) {
      statusStr = 'SAFE';
    } else if (percentage >= subject.requiredPercentage - 10) {
      statusStr = 'WARNING';
    }

    return {
      'total_classes': totalClasses,
      'attended_classes': attended,
      'percentage': percentage,
      'safe_bunks': safeBunks,
      'status': statusStr,
    };
  }

  int? classesNeededToRecover(double attended, double total, double reqFrac) {
    if (reqFrac <= 0 || reqFrac >= 1) return null;
    final current = total > 0 ? attended / total : 0.0;
    if (current >= reqFrac) return null;
    
    final num = reqFrac * total - attended;
    final den = 1 - reqFrac;
    final x = num / den;
    return max(x.ceil(), 0);
  }

  Future<DashboardSummary> getDashboardSummary() async {
    final subjectsData = await db.getSubjects();
    final List<SubjectDashboard> rows = [];
    double totalAttended = 0;
    double totalClasses = 0;

    for (var sMap in subjectsData) {
      final subject = Subject.fromJson(sMap);
      final stats = await computeSubjectStats(subject);
      rows.add(SubjectDashboard(
        subjectId: subject.id,
        name: subject.name,
        code: subject.code,
        color: subject.color,
        requiredPercentage: subject.requiredPercentage,
        totalClasses: stats['total_classes'],
        attendedClasses: stats['attended_classes'],
        percentage: stats['percentage'],
        safeBunks: stats['safe_bunks'],
        status: stats['status'],
      ));
      totalAttended += stats['attended_classes'];
      totalClasses += stats['total_classes'];
    }

    final overall = totalClasses > 0 ? (totalAttended / totalClasses * 100) : 0.0;
    return DashboardSummary(
      overallPercentage: overall,
      subjects: rows,
    );
  }

  Future<List<Map<String, dynamic>>> getCalendarMonth(int year, int month) async {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final result = <Map<String, dynamic>>[];
    final database = await db.database;

    for (var day = 1; day <= daysInMonth; day++) {
      final d = DateTime(year, month, day);
      final dStr = d.toIso8601String().split('T').first;
      final slots = await getSlotsForDate(d);
      
      if (slots.isEmpty) {
        result.add({'date': dStr, 'summary': 'HOLIDAY'});
        continue;
      }

      final records = await database.rawQuery('''
        SELECT a.status FROM attendance_records a
        JOIN class_slots c ON a.class_slot_id = c.id
        WHERE a.date = ?
      ''', [dStr]);

      final statuses = records.map((r) => r['status'] as String).toSet();
      String summary;
      if (statuses.isEmpty) {
        summary = 'PENDING';
      } else if (statuses.length == 1 && statuses.contains('PRESENT')) {
        summary = 'ALL_PRESENT';
      } else if (statuses.contains('ABSENT')) {
        summary = 'HAS_ABSENT';
      } else {
        summary = 'MIXED';
      }
      result.add({'date': dStr, 'summary': summary});
    }
    return result;
  }

  Future<List<AttendanceRecord>> getDayAttendance(DateTime date) async {
    await ensureAttendanceForDate(date);
    final dStr = date.toIso8601String().split('T').first;
    final database = await db.database;
    
    final records = await database.rawQuery('''
      SELECT a.*, c.subject_id, s.name as subject_name, c.start_time, c.end_time 
      FROM attendance_records a
      JOIN class_slots c ON a.class_slot_id = c.id
      JOIN subjects s ON c.subject_id = s.id
      WHERE a.date = ?
    ''', [dStr]);
    
    return records.map((r) => AttendanceRecord.fromJson(r)).toList();
  }

  Future<void> overrideAttendance(int recordId, AttendanceStatus status) async {
    final database = await db.database;
    await database.update(
      'attendance_records',
      {'status': statusToString(status), 'auto_marked': 0},
      where: 'id = ?',
      whereArgs: [recordId],
    );
  }

  Future<Map<String, dynamic>> getTrend(int subjectId) async {
    final database = await db.database;
    final subjectMap = (await database.query('subjects', where: 'id = ?', whereArgs: [subjectId])).first;
    final subject = Subject.fromJson(subjectMap);

    final records = await database.rawQuery('''
      SELECT a.* FROM attendance_records a
      JOIN class_slots c ON a.class_slot_id = c.id
      WHERE c.subject_id = ?
      ORDER BY a.date ASC
    ''', [subjectId]);

    final trend = <Map<String, dynamic>>[];
    double cumTotal = 0;
    double cumAttended = 0;

    for (var r in records) {
      final status = r['status'] as String;
      if (status == 'NO_CLASS') continue;
      
      final units = (r['units'] as num).toDouble();
      cumTotal += units;
      if (status == 'PRESENT') cumAttended += units;
      
      final pct = cumTotal > 0 ? (cumAttended / cumTotal * 100) : 0.0;
      trend.add({'date': r['date'], 'cumulative_percentage': pct});
    }

    final stats = await computeSubjectStats(subject);
    final reqFrac = subject.requiredPercentage / 100.0;
    final below = stats['percentage'] < subject.requiredPercentage;
    final recover = below ? classesNeededToRecover(stats['attended_classes'], stats['total_classes'], reqFrac) : null;

    return {
      'subject_id': subject.id,
      'trend': trend,
      'is_below_required': below,
      'classes_needed_to_recover': recover,
      'max_missable_now': stats['safe_bunks'],
    };
  }

  Future<Map<String, dynamic>> predict(int subjectId, {required int missed}) async {
    final database = await db.database;
    final subjectMap = (await database.query('subjects', where: 'id = ?', whereArgs: [subjectId])).first;
    final subject = Subject.fromJson(subjectMap);
    
    final stats = await computeSubjectStats(subject);
    
    final projectedTotal = stats['total_classes'] + missed;
    final projectedAttended = stats['attended_classes']; // Missed all future
    
    final projectedPct = projectedTotal > 0 ? (projectedAttended / projectedTotal * 100) : 0.0;
    
    return {
      'subject_id': subject.id,
      'current_percentage': stats['percentage'],
      'projected_percentage': projectedPct,
      'required_percentage': subject.requiredPercentage,
      'will_be_below_required': projectedPct < subject.requiredPercentage,
    };
  }
}
