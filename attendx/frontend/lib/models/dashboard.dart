class SubjectDashboard {
  final int subjectId;
  final String name;
  final String? code;
  final String color;
  final double requiredPercentage;
  final double totalClasses;
  final double attendedClasses;
  final double percentage;
  final int safeBunks;
  final String status; // SAFE | WARNING | CRITICAL

  SubjectDashboard({
    required this.subjectId,
    required this.name,
    this.code,
    required this.color,
    required this.requiredPercentage,
    required this.totalClasses,
    required this.attendedClasses,
    required this.percentage,
    required this.safeBunks,
    required this.status,
  });

  factory SubjectDashboard.fromJson(Map<String, dynamic> json) => SubjectDashboard(
        subjectId: json['subject_id'],
        name: json['name'],
        code: json['code'],
        color: json['color'] ?? '#6750A4',
        requiredPercentage: (json['required_percentage'] as num).toDouble(),
        totalClasses: (json['total_classes'] as num).toDouble(),
        attendedClasses: (json['attended_classes'] as num).toDouble(),
        percentage: (json['percentage'] as num).toDouble(),
        safeBunks: json['safe_bunks'],
        status: json['status'],
      );
}

class DashboardSummary {
  final double overallPercentage;
  final List<SubjectDashboard> subjects;

  DashboardSummary({required this.overallPercentage, required this.subjects});

  factory DashboardSummary.fromJson(Map<String, dynamic> json) => DashboardSummary(
        overallPercentage: (json['overall_percentage'] as num).toDouble(),
        subjects: (json['subjects'] as List).map((e) => SubjectDashboard.fromJson(e)).toList(),
      );
}
