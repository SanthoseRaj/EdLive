import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:school_app/providers/teacher_settings_provider.dart';

import 'package:school_app/widgets/teacher_app_bar.dart';

import 'teacher_menu_drawer.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<SettingsProvider>().loadSettings(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
        ),
        child: Scaffold(
          backgroundColor: Colors.white,
          drawer: const MenuDrawer(),
          body: Column(
            children: [
              const TeacherAppBar(),
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: _selectedTab == 0
                    ? _buildDashboardSettings(settings)
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          const SizedBox(height: 50),
                          Container(
                            height: 50,
                            width: MediaQuery.of(context).size.width * 0.8,
                            decoration: BoxDecoration(
                              color: const Color(0xFF29ABE2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text(
                                'Reset password',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardSettings(SettingsProvider settings) {
    if (settings.isLoading && !settings.hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      itemCount: settings.options.length,
      itemBuilder: (context, index) {
        final option = settings.options[index];
        final value = settings.isVisible(option.key);
        final messenger = ScaffoldMessenger.of(context);

        return Column(
          children: [
            Theme(
              data: Theme.of(context).copyWith(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
                switchTheme: SwitchThemeData(
                  thumbColor: WidgetStateProperty.resolveWith<Color>(
                    (states) => states.contains(WidgetState.selected)
                        ? Colors.white
                        : Colors.grey.shade400,
                  ),
                  trackColor: WidgetStateProperty.resolveWith<Color>(
                    (states) => states.contains(WidgetState.selected)
                        ? const Color(0xFF77FF00)
                        : Colors.grey.shade300,
                  ),
                ),
              ),
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: Text(option.title),
                value: value,
                tileColor: Colors.transparent,
                onChanged: (newValue) async {
                  try {
                    await settings.updateVisibility(option.key, newValue);
                  } catch (error) {
                    if (!mounted) {
                      return;
                    }

                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          error.toString().replaceFirst('Exception: ', ''),
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
            if (index < settings.options.length - 1)
              const Divider(height: 0, indent: 16),
          ],
        );
      },
    );
  }

  Widget _noSplashButton({
    required VoidCallback onPressed,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _noSplashButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '< Back',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                padding: const EdgeInsets.all(9),
                decoration: const BoxDecoration(
                  color: Color(0xFF2E3192),
                  shape: BoxShape.rectangle,
                ),
                child: SvgPicture.asset(
                  'assets/icons/settings.svg',
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 13),
              const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 34,
                  color: Color(0xFF292E84),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _noSplashButton(
              onPressed: () => setState(() => _selectedTab = 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Text(
                      'Customize dashboard',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _selectedTab == 0
                            ? const Color(0xFF29ABE2)
                            : Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 2,
                    width: 120,
                    color: _selectedTab == 0
                        ? const Color(0xFF29ABE2)
                        : Colors.transparent,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _noSplashButton(
              onPressed: () => setState(() => _selectedTab = 1),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Text(
                      'Other settings',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _selectedTab == 1
                            ? const Color(0xFF29ABE2)
                            : Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 2,
                    width: 120,
                    color: _selectedTab == 1
                        ? const Color(0xFF29ABE2)
                        : Colors.transparent,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
