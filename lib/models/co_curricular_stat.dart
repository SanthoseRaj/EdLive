class CoCurricularStat {
  final String activityName;
  final String categoryName;
  final String enrollmentCount;
  final String className;
  final DateTime? createdAt;

  CoCurricularStat({
    required this.activityName,
    required this.categoryName,
    required this.enrollmentCount,
    required this.className,
    this.createdAt,
  });

  factory CoCurricularStat.fromJson(Map<String, dynamic> json) {
    return CoCurricularStat(
      activityName: json['activity_name'] ?? '',
      categoryName: json['category_name'] ?? '',
      enrollmentCount: json['enrollment_count'] ?? '0',
      className: json['class_name'] ?? '',
      createdAt: DateTime.tryParse(
        (json['created_at'] ?? json['createdAt'] ?? '').toString(),
      ),
    );
  }
}
