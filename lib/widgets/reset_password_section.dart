import 'package:flutter/material.dart';

import 'package:school_app/services/user_account_service.dart';

class ResetPasswordSection extends StatefulWidget {
  const ResetPasswordSection({super.key});

  @override
  State<ResetPasswordSection> createState() => _ResetPasswordSectionState();
}

class _ResetPasswordSectionState extends State<ResetPasswordSection> {
  final _formKey = GlobalKey<FormState>();
  final _service = UserAccountService();
  final _fullnameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  UserAccountDraft? _draft;
  bool _isExpanded = false;
  bool _isLoadingAccount = false;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _loadErrorTitle;
  String? _submissionErrorTitle;
  String? _submissionErrorMessage;
  String? _loadError;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    _fullnameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _toggleExpanded() async {
    if (_isExpanded) {
      setState(() {
        _isExpanded = false;
        _passwordController.clear();
        _confirmPasswordController.clear();
        _submissionErrorTitle = null;
        _submissionErrorMessage = null;
        _fieldErrors = const {};
      });
      return;
    }

    setState(() {
      _isExpanded = true;
      _submissionErrorTitle = null;
      _submissionErrorMessage = null;
      _fieldErrors = const {};
    });
    await _ensureDraftLoaded();
  }

  Future<void> _ensureDraftLoaded({bool forceReload = false}) async {
    if (_isLoadingAccount) {
      return;
    }
    if (!forceReload && _draft != null && _loadError == null) {
      return;
    }

    setState(() {
      _isLoadingAccount = true;
      _loadErrorTitle = null;
      _loadError = null;
    });

    try {
      final draft = await _service.loadCurrentAccountDraft();
      _applyDraft(draft);

      if (!mounted) {
        return;
      }

      setState(() {
        _draft = draft;
        _fieldErrors = const {};
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      final (title, message) = _normalizeUiError(error);

      setState(() {
        _loadErrorTitle = title;
        _loadError = message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAccount = false;
        });
      }
    }
  }

  void _applyDraft(UserAccountDraft draft) {
    _fullnameController.text = draft.fullname;
    _usernameController.text = draft.username;
    _emailController.text = draft.email;
    _phoneController.text = draft.phoneNumber;
  }

  Future<void> _submit() async {
    if (_isSubmitting || _isLoadingAccount) {
      return;
    }
    if (_draft == null) {
      await _ensureDraftLoaded();
      if (_draft == null) {
        return;
      }
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionErrorTitle = null;
      _submissionErrorMessage = null;
      _fieldErrors = const {};
    });

    try {
      final updatedDraft = await _service.updateCurrentUser(
        draft: UserAccountDraft(
          userId: _draft!.userId,
          fullname: _fullnameController.text.trim(),
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          usertype: _draft!.usertype,
        ),
        password: _passwordController.text.trim(),
      );

      _applyDraft(updatedDraft);

      if (!mounted) {
        return;
      }

      setState(() {
        _draft = updatedDraft;
        _isExpanded = false;
        _passwordController.clear();
        _confirmPasswordController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      final (title, message) = _normalizeUiError(error);
      final fieldErrors = error is UserAccountException
          ? error.fieldErrors
          : const <String, String>{};

      setState(() {
        _submissionErrorTitle = title;
        _submissionErrorMessage = message;
        _fieldErrors = fieldErrors;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD6DCE5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF29ABE2), width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  String? _requiredValidator(String? value, String label) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '$label is required.';
    }
    return null;
  }

  void _clearFieldError(String fieldKey) {
    if (_fieldErrors.isEmpty &&
        _submissionErrorTitle == null &&
        _submissionErrorMessage == null) {
      return;
    }

    setState(() {
      if (_fieldErrors.containsKey(fieldKey)) {
        _fieldErrors = Map<String, String>.from(_fieldErrors)..remove(fieldKey);
      }

      if (_submissionErrorTitle != null || _submissionErrorMessage != null) {
        _submissionErrorTitle = null;
        _submissionErrorMessage = null;
      }
    });
  }

  (String, String) _normalizeUiError(Object error) {
    if (error is UserAccountException) {
      return (error.title, error.message);
    }

    final message = error.toString().replaceFirst('Exception: ', '').trim();
    return (
      'Reset password section',
      message.isEmpty ? 'Something went wrong. Please try again.' : message,
    );
  }

  Widget _buildErrorBanner({
    required String title,
    required String message,
    VoidCallback? onRetry,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDA4AF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFFB42318),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF7A271A),
              height: 1.4,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    if (_isLoadingAccount) {
      return const Padding(
        padding: EdgeInsets.only(top: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return _buildErrorBanner(
        title: _loadErrorTitle ?? 'Reset password section',
        message: _loadError!,
        onRetry: () => _ensureDraftLoaded(forceReload: true),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Use the same full name, username, and email already saved for this account, then set a new password.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF4A5568),
                height: 1.4,
              ),
            ),
            if (_submissionErrorMessage != null) ...[
              _buildErrorBanner(
                title: _submissionErrorTitle ?? 'Reset password section',
                message: _submissionErrorMessage!,
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _fullnameController,
              decoration: _inputDecoration(
                'Full name',
              ).copyWith(errorText: _fieldErrors['fullname']),
              onChanged: (_) => _clearFieldError('fullname'),
              validator: (value) => _requiredValidator(value, 'Full name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _usernameController,
              decoration: _inputDecoration(
                'Username',
              ).copyWith(errorText: _fieldErrors['username']),
              onChanged: (_) => _clearFieldError('username'),
              validator: (value) => _requiredValidator(value, 'Username'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDecoration(
                'Email',
              ).copyWith(errorText: _fieldErrors['email']),
              onChanged: (_) => _clearFieldError('email'),
              validator: (value) {
                final requiredMessage = _requiredValidator(value, 'Email');
                if (requiredMessage != null) {
                  return requiredMessage;
                }

                final trimmed = value!.trim();
                if (!trimmed.contains('@') || !trimmed.contains('.')) {
                  return 'Enter a valid email address.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: _inputDecoration(
                'Phone number',
              ).copyWith(errorText: _fieldErrors['phoneNumber']),
              onChanged: (_) => _clearFieldError('phoneNumber'),
              validator: (value) => _requiredValidator(value, 'Phone number'),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: _inputDecoration('User type'),
              child: Text(
                (_draft?.usertype ?? '').isNotEmpty ? _draft!.usertype : '-',
                style: const TextStyle(fontSize: 16, color: Color(0xFF1F2937)),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: _inputDecoration('New password').copyWith(
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
              validator: (value) {
                final requiredMessage = _requiredValidator(
                  value,
                  'New password',
                );
                if (requiredMessage != null) {
                  return requiredMessage;
                }

                if (value!.trim().length < 6) {
                  return 'Password must be at least 6 characters.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              decoration: _inputDecoration('Confirm password').copyWith(
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                ),
              ),
              validator: (value) {
                final requiredMessage = _requiredValidator(
                  value,
                  'Confirm password',
                );
                if (requiredMessage != null) {
                  return requiredMessage;
                }

                if (value!.trim() != _passwordController.text.trim()) {
                  return 'Passwords do not match.';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF29ABE2),
                  disabledBackgroundColor: const Color(0xFF9ADAF4),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save new password',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            if (_draft != null) ...[
              const SizedBox(height: 12),
              Text(
                'User ID: ${_draft!.userId}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF718096)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _toggleExpanded,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF29ABE2),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _isExpanded ? 'Close reset password' : 'Reset password',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          if (_isExpanded) _buildFormCard(),
        ],
      ),
    );
  }
}
