import 'dashboard_settings_base.dart';

class StudentSettingsProvider extends DashboardSettingsBase {
  StudentSettingsProvider()
    : super(
        storageKey: 'student_dashboard_settings_overrides',
        options: const [
          DashboardSettingOption(
            key: 'achievements',
            title: 'Achievements',
            apiManaged: true,
          ),
          DashboardSettingOption(
            key: 'subjects',
            title: 'Syllabus',
            apiManaged: true,
          ),
          DashboardSettingOption(
            key: 'messages',
            title: 'Message',
            apiManaged: true,
          ),
          DashboardSettingOption(
            key: 'transport',
            title: 'School bus',
            apiManaged: true,
          ),
          DashboardSettingOption(
            key: 'cocurricular',
            title: 'Co curricular activities',
            apiManaged: true,
          ),
        ],
      );
}
