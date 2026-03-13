import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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

  bool _obscurePassword = true; // add this variable inside your _LoginPageState

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    final url = Uri.parse(
      'https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/auth/login',
    );

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': _usernameController.text.trim(),
          'password': _passwordController.text.trim(),
        }),
      );

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final token = data['token'];
        final user = data['user'];
        final userType = user['usertype']?.toString().toLowerCase();

        if (token != null && userType != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);
          await prefs.setString('user_type', userType);
          await prefs.setString(
            'user_data',
            jsonEncode(user),
          ); // store complete user info

          if (userType == 'student' && user['student_id'] != null) {
            await prefs.setInt(
              'student_id',
              int.parse(user['student_id'].toString()),
            );
          }

          if (userType == 'teacher') {
            Navigator.pushReplacementNamed(context, '/dashboard');
          } else if (userType == 'student' || userType == 'parent') {
            // ✅ Fetch children first
            final childrenResponse = await http.get(
              Uri.parse(
                'https://schoolmanagement.canadacentral.cloudapp.azure.com:443/api/student/parents/children',
              ),
              headers: {
                'accept': 'application/json',
                'Authorization': 'Bearer $token',
              },
            );

            if (childrenResponse.statusCode == 200) {
              final List<dynamic> childrenData = json.decode(
                childrenResponse.body,
              );

              if (childrenData.length == 1) {
                // Only 1 child → go directly to StudentDashboardPage
                final child = childrenData[0];
                await prefs.setString(
                  'selected_child',
                  jsonEncode({
                    'id': child['id'],
                    'user_id': child['user_id'],
                    'name': child['full_name'],
                    'image': child['profile_img'] != null
                        ? 'https://schoolmanagement.canadacentral.cloudapp.azure.com:443${child['profile_img']}'
                        : '',
                    'class': child['class_name'] ?? '',
                    'class_id': child['class_id'],
                    'notification': 0,
                  }),
                );
                await prefs.setInt('student_id', child['id']);
                await prefs.setInt('class_id', child['class_id']);

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StudentDashboardPage(
                      childData: json.decode(
                        prefs.getString('selected_child')!,
                      ),
                    ),
                  ),
                );
              } else {
                // 2 or more children → go to SelectChildPage
                Navigator.pushReplacementNamed(
                  context,
                  '/select-child',
                  arguments: user,
                );
              }
            } else {
              // Failed to fetch children → fallback to SelectChildPage
              Navigator.pushReplacementNamed(
                context,
                '/select-child',
                arguments: user,
              );
            }
          } else {
            _showError('Missing token or user type.');
          }
        }
      } else {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['message'] ?? 'Login failed';
        _showError(errorMessage);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('An error occurred. Please try again.');
    }
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
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App Logo
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
