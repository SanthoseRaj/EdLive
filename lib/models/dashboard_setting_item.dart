class DashboardSettingItem {
  final String elementKey;
  final String title;
  final String subtitle;
  final String? iconName;
  final int defaultPosition;
  final bool isStatic;
  final String routePath;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? svgIcon;
  final bool? isEnabled;
  final int? position;

  const DashboardSettingItem({
    required this.elementKey,
    required this.title,
    required this.subtitle,
    required this.iconName,
    required this.defaultPosition,
    required this.isStatic,
    required this.routePath,
    required this.createdAt,
    required this.updatedAt,
    required this.svgIcon,
    required this.isEnabled,
    required this.position,
  });

  bool get effectiveEnabled => isEnabled ?? true;

  factory DashboardSettingItem.fromJson(Map<String, dynamic> json) {
    return DashboardSettingItem(
      elementKey: json['element_key']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      iconName: json['icon_name']?.toString(),
      defaultPosition: _asInt(json['default_position']),
      isStatic: _asBool(json['is_static']),
      routePath: json['route_path']?.toString() ?? '',
      createdAt: _asDateTime(json['created_at']),
      updatedAt: _asDateTime(json['updated_at']),
      svgIcon: json['svg_icon']?.toString(),
      isEnabled: _asNullableBool(json['is_enabled']),
      position: _asNullableInt(json['position']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _asNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }

  static bool _asBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }

    final normalized = value?.toString().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }

  static bool? _asNullableBool(dynamic value) {
    if (value == null) {
      return null;
    }
    return _asBool(value);
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }
}
