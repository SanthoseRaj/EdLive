import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:school_app/config/config.dart';

import 'students/student_dashboard.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override

  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  int? _extractPositiveInt(dynamic value) {
    if (value is int && value > 0) {
      return value;
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }
    if (value is List && value.isNotEmpty) {
      return _extractPositiveInt(value.first);
    }
    return null;
  }

  Map<String, dynamic> _buildSelectedChild(Map<String, dynamic> child) {
    final selectedChild = Map<String, dynamic>.from(child);
    final profilePath =
        child['profile_img'] ?? child['profile_image'] ?? child['image'];

    selectedChild['name'] = child['full_name'] ?? child['name'] ?? '';
    selectedChild['image'] =
        profilePath != null && profilePath.toString().trim().isNotEmpty
        ? AppConfig.absoluteUrl(profilePath.toString())
        : '';
    selectedChild['class'] =
        child['class_name'] ?? child['classname'] ?? child['class'] ?? '';
    selectedChild['notification'] = child['notification'] ?? 0;

    return selectedChild;
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http
          .post(
            AppConfig.apiUri('/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'username': _usernameController.text.trim(),
              'password': _passwordController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        _showError(_extractErrorMessage(response.body));
        return;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final token = data['token']?.toString();
      final user = data['user'] as Map<String, dynamic>?;
      final userType = user?['usertype']?.toString().toLowerCase();

      if (token == null || user == null || userType == null) {
        _showError('Missing token or user type.');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setString('user_type', userType);
      await prefs.setString('user_data', jsonEncode(user));

      if (userType == 'student' && user['student_id'] != null) {
        await prefs.setInt(
          'student_id',
          int.parse(user['student_id'].toString()),
        );
      }

      if (!mounted) {
        return;
      }

      if (userType == 'teacher') {
        final teacherId =
            _extractPositiveInt(user['staffid']) ??
            _extractPositiveInt(user['teacher_id']) ??
            _extractPositiveInt(user['staff_id']) ??
            _extractPositiveInt(user['id']);
        if (teacherId != null) {
          await prefs.setInt('teacher_id', teacherId);
        }
        await prefs.remove('selected_child');
        await prefs.remove('student_id');
        await prefs.remove('class_id');
        if (!mounted) {
          return;
        }
        Navigator.pushReplacementNamed(context, '/dashboard');
        return;
      }

      if (userType == 'student' || userType == 'parent') {
        await prefs.remove('teacher_id');
        await _handleStudentOrParentLogin(
          prefs: prefs,
          token: token,
          user: user,
        );
        return;
      }

      _showError('Unsupported user type.');
    } on TimeoutException catch (e) {
      _showError(AppConfig.networkErrorMessage(e));
    } on http.ClientException catch (e) {
      _showError(AppConfig.networkErrorMessage(e));
    } catch (e) {
      _showError(AppConfig.networkErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleStudentOrParentLogin({
    required SharedPreferences prefs,
    required String token,
    required Map<String, dynamic> user,
  }) async {
    try {
      final childrenResponse = await http
          .get(
            AppConfig.apiUri('/student/parents/children'),
            headers: {
              'accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 20));

      if (childrenResponse.statusCode != 200) {
        if (!mounted) {
          return;
        }
        Navigator.pushReplacementNamed(
          context,
          '/select-child',
          arguments: user,
        );
        return;
      }

      final childrenData = json.decode(childrenResponse.body) as List<dynamic>;
      if (childrenData.length != 1) {
        if (!mounted) {
          return;
        }
        Navigator.pushReplacementNamed(
          context,
          '/select-child',
          arguments: user,
        );
        return;
      }

      final child = childrenData.first as Map<String, dynamic>;
      final selectedChild = _buildSelectedChild(child);

      await prefs.setString('selected_child', jsonEncode(selectedChild));

      final selectedType = child['user_type']?.toString().toLowerCase() ?? '';
      final opensTeacherDashboard =
          selectedType == 'staff' || selectedType == 'teacher';

      if (opensTeacherDashboard) {
        final teacherId =
            _extractPositiveInt(child['staffid']) ??
            _extractPositiveInt(child['teacher_id']) ??
            _extractPositiveInt(child['staff_id']) ??
            _extractPositiveInt(child['id']) ??
            _extractPositiveInt(child['user_id']);
        if (teacherId != null) {
          await prefs.setInt('teacher_id', teacherId);
        }
        await prefs.remove('student_id');
        await prefs.remove('class_id');

        if (!mounted) {
          return;
        }

        Navigator.pushReplacementNamed(context, '/dashboard');
        return;
      }

      await prefs.setInt('student_id', int.parse(child['id'].toString()));
      await prefs.setInt('class_id', int.parse(child['class_id'].toString()));

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StudentDashboardPage(childData: selectedChild),
        ),
      );
    } on TimeoutException catch (e) {
      _showError(AppConfig.networkErrorMessage(e));
    } on http.ClientException catch (e) {
      _showError(AppConfig.networkErrorMessage(e));
    } catch (_) {
      if (!mounted) {
        return;
      }
      Navigator.pushReplacementNamed(context, '/select-child', arguments: user);
    }
  }

  String _extractErrorMessage(String responseBody) {
    try {
      final decoded = json.decode(responseBody);
      if (decoded is Map<String, dynamic>) {
        return decoded['message']?.toString() ?? 'Login failed';
      }
    } catch (_) {}

    return 'Login failed';
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Login Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.school, size: 36, color: Colors.lightBlue),
                    const SizedBox(width: 10),
                    RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'ED',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D47A1),
                            ),
                          ),
                          TextSpan(
                            text: 'Live',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.lightBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                const Text(
                  'Login',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Login',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
