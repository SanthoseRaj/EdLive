class Student {
  final int id;
  final String studentName;
  final String className;
  final String? profileImagePath;

  Student({
    required this.id,
    required this.studentName,
    required this.className,
    this.profileImagePath,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'],
      studentName: json['student_name'],
      className: json['class_name'] ?? '',
      profileImagePath:
          json['profile_img']?.toString() ??
          json['profileImage']?.toString() ??
          json['profile_image']?.toString() ??
          json['image']?.toString(),
    );
  }
}
