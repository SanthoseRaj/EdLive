import 'package:flutter/foundation.dart';

import '../models/dashboard_setting_item.dart';
import '../services/dashboard_settings_service.dart';

class DashboardSettingOption {
  final String key;
  final String title;
  final bool apiManaged;
  final bool defaultValue;

  const DashboardSettingOption({
    required this.key,
    required this.title,
    this.apiManaged = false,
    this.defaultValue = true,
  });
}

abstract class DashboardSettingsBase extends ChangeNotifier {
  DashboardSettingsBase({
    required String storageKey,
    required List<DashboardSettingOption> options,
    DashboardSettingsService? service,
  }) : _storageKey = storageKey,
       _options = List.unmodifiable(options),
       _service = service ?? DashboardSettingsService(),
       _visibility = {
         for (final option in options) option.key: option.defaultValue,
       };

  final String _storageKey;
  final List<DashboardSettingOption> _options;
  final DashboardSettingsService _service;

  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _error;
  Map<String, bool> _visibility;
  Map<String, bool> _overrides = {};

  List<DashboardSettingOption> get options => _options;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get error => _error;

  bool isVisible(String key) {
    return _visibility[key] ?? _defaultValueFor(key);
  }

  Future<void> loadSettings({bool forceRefresh = false}) async {
    if (_isLoading) {
      return;
    }
    if (_hasLoaded && !forceRefresh) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final remoteItems = await _service.fetchDashboardSettings();
      _overrides = await _service.loadOverrides(_storageKey);
      final remoteByKey = {
        for (final item in remoteItems) item.elementKey: item,
      };

      _visibility = {
        for (final option in _options)
          option.key: _resolveVisibility(
            option: option,
            remoteItem: remoteByKey[option.key],
            overrides: _overrides,
          ),
      };
      _error = null;
    } catch (error) {
      _error = error.toString();
    } finally {
      _hasLoaded = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateVisibility(String key, bool value) async {
    if (!_visibility.containsKey(key) || _visibility[key] == value) {
      return;
    }

    final previousValue = _visibility[key]!;
    final hadOverride = _overrides.containsKey(key);
    final previousOverride = _overrides[key];
    final option = _optionFor(key);

    _visibility = {..._visibility, key: value};
    _error = null;
    notifyListeners();

    try {
      if (option?.apiManaged == true) {
        await _service.updateDashboardSetting(
          elementKey: key,
          isEnabled: value,
          position: _apiManagedPositionFor(key),
        );
      }

      _overrides = {..._overrides, key: value};
      await _service.saveOverrides(_storageKey, _overrides);
    } catch (error) {
      _visibility = {..._visibility, key: previousValue};

      if (hadOverride) {
        _overrides = {..._overrides, key: previousOverride!};
      } else {
        final nextOverrides = {..._overrides};
        nextOverrides.remove(key);
        _overrides = nextOverrides;
      }

      _error = error.toString();
      notifyListeners();
      rethrow;
    }

    notifyListeners();
  }

  bool _resolveVisibility({
    required DashboardSettingOption option,
    required DashboardSettingItem? remoteItem,
    required Map<String, bool> overrides,
  }) {
    final localOverride = overrides[option.key];
    if (localOverride != null) {
      return localOverride;
    }
    if (option.apiManaged && remoteItem != null) {
      return remoteItem.effectiveEnabled;
    }
    return option.defaultValue;
  }

  bool _defaultValueFor(String key) {
    for (final option in _options) {
      if (option.key == key) {
        return option.defaultValue;
      }
    }
    return true;
  }

  DashboardSettingOption? _optionFor(String key) {
    for (final option in _options) {
      if (option.key == key) {
        return option;
      }
    }
    return null;
  }

  int _apiManagedPositionFor(String key) {
    var position = 0;

    for (final option in _options) {
      if (!option.apiManaged) {
        continue;
      }
      if (option.key == key) {
        return position;
      }
      position++;
    }

    return 0;
  }
}
