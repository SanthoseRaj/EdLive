import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:school_app/config/config.dart';
import 'package:school_app/services/user_account_service.dart';

import 'students/student_dashboard.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final UserAccountService _userAccountService = UserAccountService();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showError('Please enter both username and password.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http
          .post(
            AppConfig.apiUri('/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'username': username, 'password': password}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        _showError(_extractHttpErrorMessage(response));
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
      _showError(_extractExceptionMessage(e));
    } on http.ClientException catch (e) {
      _showError(_extractExceptionMessage(e));
    } catch (e) {
      _showError(_extractExceptionMessage(e));
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

  String _extractHttpErrorMessage(http.Response response) {
    final statusCode = response.statusCode;
    final reasonPhrase = response.reasonPhrase?.trim();
    final responseBody = utf8
        .decode(response.bodyBytes, allowMalformed: true)
        .trim();
    final detail = _extractErrorDetail(responseBody);

    if (_isInvalidCredentialsError(
      statusCode: statusCode,
      detail: detail,
      reasonPhrase: reasonPhrase,
    )) {
      return 'Username or password is incorrect. Please try again.';
    }

    if (detail != null && detail.isNotEmpty) {
      return detail;
    }

    if (reasonPhrase != null && reasonPhrase.isNotEmpty) {
      return 'Login failed. $reasonPhrase';
    }

    if (statusCode >= 500) {
      return 'Server error while logging in. Please try again.';
    }

    return 'Login failed. Please try again.';
  }

  bool _isInvalidCredentialsError({
    required int statusCode,
    required String? detail,
    required String? reasonPhrase,
  }) {
    if (statusCode == 401) {
      return true;
    }

    final normalizedDetail = detail?.toLowerCase() ?? '';
    final normalizedReason = reasonPhrase?.toLowerCase() ?? '';
    final combinedMessage = '$normalizedDetail $normalizedReason';
    const invalidCredentialHints = <String>[
      'invalid credential',
      'invalid credentials',
      'invalid username',
      'invalid password',
      'invalid username or password',
      'incorrect credential',
      'incorrect credentials',
      'incorrect password',
      'wrong password',
      'wrong username',
      'bad credentials',
      'username or password',
      'login failed',
    ];

    if (statusCode != 400 && statusCode != 403) {
      return false;
    }

    return invalidCredentialHints.any(combinedMessage.contains);
  }

  String _extractExceptionMessage(Object error) {
    final rawMessage = error.toString().trim();
    final cleanedMessage = rawMessage
        .replaceFirst(RegExp(r'^(Exception|Error):\s*'), '')
        .replaceFirst(RegExp(r'^(ClientException|TimeoutException):\s*'), '')
        .trim();

    if (cleanedMessage.isEmpty) {
      return 'Login request failed.';
    }

    return _truncateMessage(cleanedMessage);
  }

  String? _extractErrorDetail(String responseBody) {
    if (responseBody.isEmpty) {
      return null;
    }

    try {
      final decoded = json.decode(responseBody);
      final message = _extractErrorText(decoded);
      if (message != null && message.isNotEmpty) {
        return _truncateMessage(message);
      }
    } on FormatException {
      // Some backends return HTML or plain-text error pages.
    }

    final plainText = _stripHtml(responseBody);
    if (plainText.isEmpty) {
      return null;
    }

    return _truncateMessage(plainText);
  }

  String? _extractErrorText(dynamic decoded) {
    if (decoded is String) {
      final message = decoded.trim();
      return message.isEmpty ? null : message;
    }

    if (decoded is List) {
      for (final item in decoded) {
        final message = _extractErrorText(item);
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
      return null;
    }

    if (decoded is Map) {
      for (final key in const ['message', 'error', 'detail', 'title', 'msg']) {
        final message = _extractErrorText(decoded[key]);
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }

      for (final value in decoded.values) {
        final message = _extractErrorText(value);
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
    }

    return null;
  }

  String _stripHtml(String value) {
    final withoutScripts = value.replaceAll(
      RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false),
      ' ',
    );
    final withoutStyles = withoutScripts.replaceAll(
      RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false),
      ' ',
    );
    final withoutTags = withoutStyles.replaceAll(RegExp(r'<[^>]+>'), ' ');

    return withoutTags
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _truncateMessage(String value, {int maxLength = 220}) {
    if (value.length <= maxLength) {
      return value;
    }

    return '${value.substring(0, maxLength).trim()}...';
  }

  Future<void> _showForgotPasswordDialog() async {
    final pageContext = context;
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController(
      text: _usernameController.text.trim().contains('@')
          ? _usernameController.text.trim()
          : '',
    );
    bool isSending = false;
    String? errorMessage;

    try {
      await showDialog<void>(
        context: pageContext,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogBuildContext, setDialogState) {
            return AlertDialog(
              title: const Text('Forgot Password'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter your registered email address. We will send a temporary password to that email.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Registered email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) {
                          return 'Registered email is required.';
                        }
                        if (!trimmed.contains('@') || !trimmed.contains('.')) {
                          return 'Enter a valid email address.';
                        }
                        return null;
                      },
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSending
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSending
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }

                          setDialogState(() {
                            isSending = true;
                            errorMessage = null;
                          });

                          final email = emailController.text.trim();
                          final dialogNavigator = Navigator.of(
                            pageContext,
                            rootNavigator: true,
                          );

                          try {
                            await _userAccountService.sendTemporaryPassword(
                              email: email,
                            );

                            if (!mounted) {
                              return;
                            }

                            dialogNavigator.pop();
                            await _showTemporaryPasswordSentDialog(email);
                          } catch (error) {
                            setDialogState(() {
                              isSending = false;
                              errorMessage = error is UserAccountException
                                  ? error.message
                                  : _extractExceptionMessage(error);
                            });
                          }
                        },
                  child: isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      emailController.dispose();
    }
  }

  Future<void> _showTemporaryPasswordSentDialog(String email) {
    final isGmail = email.toLowerCase().contains('@gmail.com');
    final message = isGmail
        ? 'A temporary password has been sent to your Gmail account ($email). Please use that temporary password to continue.'
        : 'A temporary password has been sent to $email. Please use that temporary password to continue.';

    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Temporary Password Sent'),
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
                    onPressed: _isLoading ? null : _showForgotPasswordDialog,
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
