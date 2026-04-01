// lib/models/dashboard_counts.dart
class DashboardCounts {
  final int notifications;
  final int todo;
  final int payments;
  final int messages;
  final int library;
  final int achievements;

  DashboardCounts({
    required this.notifications,
    required this.todo,
    required this.payments,
    required this.messages,
    required this.library,
    required this.achievements,
  });

  factory DashboardCounts.fromJson(Map<String, dynamic> json) {
    return DashboardCounts(
      notifications: json['notifications'] ?? 0,
      todo: json['todo'] ?? 0,
      payments: json['payments'] ?? 0,
      messages: json['messages'] ?? 0,
      library: json['library'] ?? 0,
      achievements: json['achievements'] ?? 0,
    );
  }

  DashboardCounts copyWith({
    int? notifications,
    int? todo,
    int? payments,
    int? messages,
    int? library,
    int? achievements,
  }) {
    return DashboardCounts(
      notifications: notifications ?? this.notifications,
      todo: todo ?? this.todo,
      payments: payments ?? this.payments,
      messages: messages ?? this.messages,
      library: library ?? this.library,
      achievements: achievements ?? this.achievements,
    );
  }
}
