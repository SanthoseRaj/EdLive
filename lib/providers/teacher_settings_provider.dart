import 'dashboard_settings_base.dart';

class SettingsProvider extends DashboardSettingsBase {
  SettingsProvider()
    : super(
        storageKey: 'teacher_dashboard_settings_overrides',
        options: const [
          DashboardSettingOption(
            key: 'achievements',
            title: 'Achievements',
            apiManaged: true,
          ),
          DashboardSettingOption(
            key: 'todo',
            title: 'My to-do list',
            apiManaged: true,
          ),
          DashboardSettingOption(key: 'pta', title: 'PTA', apiManaged: true),
          DashboardSettingOption(
            key: 'library',
            title: 'Library',
            apiManaged: true,
          ),
          DashboardSettingOption(
            key: 'subjects',
            title: 'Syllabus',
            apiManaged: true,
          ),
          DashboardSettingOption(key: 'special_care', title: 'Special care'),
          DashboardSettingOption(
            key: 'cocurricular',
            title: 'Co curricular activities',
            apiManaged: true,
          ),
          DashboardSettingOption(key: 'quick_notes', title: 'Quick notes'),
          DashboardSettingOption(key: 'resources', title: 'Resources'),
        ],
      );
}
