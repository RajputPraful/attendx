class Subject {
  final int id;
  final String name;
  final String? code;
  final double requiredPercentage;
  final String color;

  Subject({
    required this.id,
    required this.name,
    this.code,
    required this.requiredPercentage,
    required this.color,
  });

  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
        id: json['id'],
        name: json['name'],
        code: json['code'],
        requiredPercentage: (json['required_percentage'] as num).toDouble(),
        color: json['color'] ?? '#6750A4',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'code': code,
        'required_percentage': requiredPercentage,
        'color': color,
      };
}
