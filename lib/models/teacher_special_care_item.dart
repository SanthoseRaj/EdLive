class SpecialCareItem {
  final int? id;
  final List<int> studentIds;
  final List<String> studentNames;
  final int categoryId;
  final String title;
  final String description;
  final String careType;
  final List<String> days;
  final String time;
  final List<String> materials;
  final List<String> tools;
  final int assignedTo;
  final String status;
  final String startDate;
  final String endDate;
  final String visibility;
  final int? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? studentName;
  final String? categoryName;
  final String? assignedToName;

  SpecialCareItem({
    this.id,
    required this.studentIds,
    this.studentNames = const [],
    required this.categoryId,
    required this.title,
    required this.description,
    required this.careType,
    required this.days,
    required this.time,
    required this.materials,
    required this.tools,
    required this.assignedTo,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.visibility,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.studentName,
    this.categoryName,
    this.assignedToName,
  });

  Map<String, dynamic> toJson() {
    return {
      "studentIds": studentIds,
      "categoryId": categoryId,
      "title": title,
      "description": description,
      "careType": careType,
      "scheduleDetails": {"days": days, "time": time},
      "resources": {"materials": materials, "tools": tools},
      "assignedTo": assignedTo,
      "status": status,
      "startDate": startDate,
      "endDate": endDate,
      "visibility": visibility,
    };
  }

  factory SpecialCareItem.fromJson(Map<String, dynamic> json) {
    final scheduleDetails = _readMap(
      json["scheduleDetails"] ?? json["schedule_details"],
    );
    final resources = _readMap(json["resources"]);

    return SpecialCareItem(
      id: _readInt(json["id"]),
      studentIds: _readIntList(json["studentIds"] ?? json["student_ids"]),
      studentNames: _readStringList(
        json["studentNames"] ?? json["student_names"],
      ),
      categoryId: _readInt(json["categoryId"] ?? json["category_id"]) ?? 0,
      title: (json["title"] ?? "").toString(),
      description: (json["description"] ?? "").toString(),
      careType: (json["careType"] ?? json["care_type"] ?? "").toString(),
      days: _readStringList(scheduleDetails["days"]),
      time: (scheduleDetails["time"] ?? "").toString(),
      materials: _readStringList(resources["materials"]),
      tools: _readStringList(resources["tools"]),
      assignedTo: _readInt(json["assignedTo"] ?? json["assigned_to"]) ?? 0,
      status: (json["status"] ?? "").toString(),
      startDate: (json["startDate"] ?? json["start_date"] ?? "").toString(),
      endDate: (json["endDate"] ?? json["end_date"] ?? "").toString(),
      visibility: (json["visibility"] ?? "").toString(),
      createdBy: _readInt(json["createdBy"] ?? json["created_by"]),
      createdAt: _readDateTime(json["createdAt"] ?? json["created_at"]),
      updatedAt: _readDateTime(json["updatedAt"] ?? json["updated_at"]),
      studentName: _readString(json["studentName"] ?? json["student_name"]),
      categoryName: _readString(json["categoryName"] ?? json["category_name"]),
      assignedToName: _readString(
        json["assignedToName"] ?? json["assigned_to_name"],
      ),
    );
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }

  static int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  static List<int> _readIntList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value.map(_readInt).whereType<int>().toList(growable: false);
  }

  static Map<String, dynamic> _readMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
    }
    return const <String, dynamic>{};
  }

  static String? _readString(dynamic value) {
    if (value == null) {
      return null;
    }

    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static List<String> _readStringList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .map((item) => item?.toString())
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}
