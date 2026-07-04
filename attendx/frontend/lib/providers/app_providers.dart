import 'package:flutter/material.dart';
import '../services/local_db.dart';
import '../services/attendance_engine.dart';
import '../models/subject.dart';
import '../models/dashboard.dart';

/// Holds subjects + dashboard summary; the single source of truth the
/// Dashboard/Subjects screens listen to via Provider.
class AppState extends ChangeNotifier {
  final LocalDb db;
  final AttendanceEngine engine;
  AppState(this.db, this.engine);

  List<Subject> subjects = [];
  DashboardSummary? dashboard;
  bool isLoading = false;
  String? error;

  /// Period duration in minutes (e.g. 50). Loaded from DB on refresh.
  int periodDurationMinutes = 50;

  Future<void> refreshAll() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await engine.ensureAttendanceForDate(DateTime.now());
      final subjectMaps = await db.getSubjects();
      subjects = subjectMaps.map((e) => Subject.fromJson(e)).toList();
      dashboard = await engine.getDashboardSummary();
      periodDurationMinutes = await db.getPeriodDurationMinutes();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addSubject(Subject s) async {
    await db.insertSubject(s.toJson());
    await refreshAll();
  }

  Future<void> deleteSubject(int id) async {
    await db.deleteSubject(id);
    await refreshAll();
  }

  Future<void> updateSubject(int id, Map<String, dynamic> patch) async {
    await db.updateSubject(id, patch);
    await refreshAll();
  }

  /// Persist a new period duration and refresh the UI.
  Future<void> setPeriodDuration(int minutes) async {
    await db.setPeriodDurationMinutes(minutes);
    periodDurationMinutes = minutes;
    notifyListeners();
  }

  /// Theme mode toggle.
  ThemeMode themeMode = ThemeMode.dark;
  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    notifyListeners();
  }
}
