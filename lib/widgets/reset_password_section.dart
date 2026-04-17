import 'package:flutter/material.dart';

import 'package:school_app/services/user_account_service.dart';

class ResetPasswordSection extends StatefulWidget {
  const ResetPasswordSection({super.key});

  @override
  State<ResetPasswordSection> createState() => _ResetPasswordSectionState();
}

class _ResetPasswordSectionState extends State<ResetPasswordSection> {
  final _forgotFormKey = GlobalKey<FormState>();
  final _changeFormKey = GlobalKey<FormState>();
  final _service = UserAccountService();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  UserAccountResetContext? _contextData;
  bool _isExpanded = false;
  bool _isLoadingContext = false;
  bool _isSendingTemporaryPassword = false;
  bool _isChangingPassword = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _loadErrorTitle;
  String? _loadErrorMessage;
  String? _forgotErrorTitle;
  String? _forgotErrorMessage;
  String? _changeErrorTitle;
  String? _changeErrorMessage;
  Map<String, String> _forgotFieldErrors = const {};
  Map<String, String> _changeFieldErrors = const {};

  bool get _hasRegisteredEmail =>
      (_contextData?.email.trim().isNotEmpty ?? false);

  @override
  void dispose() {
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _toggleExpanded() async {
    if (_isExpanded) {
      setState(() {
        _isExpanded = false;
        _clearTransientState();
      });
      return;
    }

    setState(() {
      _isExpanded = true;
      _clearAllErrors();
    });

    await _ensureContextLoaded();
  }

  void _clearTransientState() {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    _clearAllErrors();
  }

  void _clearAllErrors() {
    _loadErrorTitle = null;
    _loadErrorMessage = null;
    _forgotErrorTitle = null;
    _forgotErrorMessage = null;
    _changeErrorTitle = null;
    _changeErrorMessage = null;
    _forgotFieldErrors = const {};
    _changeFieldErrors = const {};
  }

  Future<void> _ensureContextLoaded({bool forceReload = false}) async {
    if (_isLoadingContext) {
      return;
    }
    if (!forceReload && _contextData != null) {
      return;
    }

    setState(() {
      _isLoadingContext = true;
      _loadErrorTitle = null;
      _loadErrorMessage = null;
    });

    try {
      final contextData = await _service.loadResetContext();
      if (!mounted) {
        return;
      }

      setState(() {
        _contextData = contextData;
        _emailController.text = contextData.email.trim();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      final (title, message) = _normalizeUiError(
        error,
        fallbackTitle: 'Password reset',
      );

      setState(() {
        _loadErrorTitle = title;
        _loadErrorMessage = message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingContext = false;
        });
      }
    }
  }

  Future<void> _sendTemporaryPassword() async {
    if (_isSendingTemporaryPassword || _isChangingPassword) {
      return;
    }
    if (!_hasRegisteredEmail) {
      setState(() {
        _forgotErrorTitle = 'Registered email missing';
        _forgotErrorMessage =
            'No email is available in this account\'s saved details.';
        _forgotFieldErrors = const {};
      });
      return;
    }
    if (!_forgotFormKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _forgotErrorTitle = null;
      _forgotErrorMessage = null;
      _forgotFieldErrors = const {};
      _isSendingTemporaryPassword = true;
    });

    try {
      final email = _contextData!.email.trim();
      await _service.sendTemporaryPassword(email: email);

      if (!mounted) {
        return;
      }

      await _showTemporaryPasswordSentDialog(email);
    } catch (error) {
      if (!mounted) {
        return;
      }

      final (title, message) = _normalizeUiError(
        error,
        fallbackTitle: 'Temporary password failed',
      );

      setState(() {
        _forgotErrorTitle = title;
        _forgotErrorMessage = message;
        _forgotFieldErrors = error is UserAccountException
            ? error.fieldErrors
            : const {};
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSendingTemporaryPassword = false;
        });
      }
    }
  }

  Future<void> _changePassword() async {
    if (_isChangingPassword || _isSendingTemporaryPassword) {
      return;
    }
    if (!_changeFormKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _changeErrorTitle = null;
      _changeErrorMessage = null;
      _changeFieldErrors = const {};
      _isChangingPassword = true;
    });

    try {
      final message = await _service.changePassword(
        currentPassword: _currentPasswordController.text.trim(),
        newPassword: _newPasswordController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) {
        return;
      }

      final (title, message) = _normalizeUiError(
        error,
        fallbackTitle: 'Change password failed',
      );

      setState(() {
        _changeErrorTitle = title;
        _changeErrorMessage = message;
        _changeFieldErrors = error is UserAccountException
            ? error.fieldErrors
            : const {};
      });
    } finally {
      if (mounted) {
        setState(() {
          _isChangingPassword = false;
        });
      }
    }
  }

  Future<void> _showTemporaryPasswordSentDialog(String email) {
    final isGmail = email.toLowerCase().contains('@gmail.com');
    final message = isGmail
        ? 'A temporary password has been sent to your Gmail account ($email). Please use that temporary password to continue.'
        : 'A temporary password has been sent to $email. Please use that temporary password to continue.';

    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Temporary Password Sent'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _clearChangeError([String? fieldKey]) {
    if (_changeErrorTitle == null &&
        _changeErrorMessage == null &&
        (fieldKey == null || !_changeFieldErrors.containsKey(fieldKey))) {
      return;
    }

    setState(() {
      _changeErrorTitle = null;
      _changeErrorMessage = null;
      if (fieldKey != null && _changeFieldErrors.containsKey(fieldKey)) {
        _changeFieldErrors = Map<String, String>.from(_changeFieldErrors)
          ..remove(fieldKey);
      }
    });
  }

  (String, String) _normalizeUiError(
    Object error, {
    required String fallbackTitle,
  }) {
    if (error is UserAccountException) {
      return (error.title, error.message);
    }

    final message = error.toString().replaceFirst('Exception: ', '').trim();
    return (
      fallbackTitle,
      message.isEmpty ? 'Something went wrong. Please try again.' : message,
    );
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

  Widget _buildErrorBanner({
    required String title,
    required String message,
    VoidCallback? onRetry,
  }) {
    return Container(
      width: double.infinity,
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

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    required ValueChanged<String> onChanged,
    String? errorText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: _inputDecoration(label).copyWith(
        errorText: errorText,
        suffixIcon: IconButton(
          onPressed: onToggleVisibility,
          icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
        ),
      ),
      onChanged: onChanged,
      validator: validator,
    );
  }

  Widget _buildForgotPasswordSection() {
    return Form(
      key: _forgotFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Forgot your current password? Send a temporary password to your registered email first.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF4A5568),
              height: 1.45,
            ),
          ),
          if (_contextData?.email.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            const Text(
              'The email below is taken from your signed-in account details and cannot be changed here.',
              style: TextStyle(fontSize: 12, color: Color(0xFF718096)),
            ),
          ],
          if (!_hasRegisteredEmail) ...[
            const SizedBox(height: 14),
            _buildErrorBanner(
              title: 'Registered email missing',
              message:
                  'No email is available in this account\'s saved details, so a temporary password cannot be sent.',
            ),
          ],
          if (_forgotErrorMessage != null) ...[
            const SizedBox(height: 14),
            _buildErrorBanner(
              title: _forgotErrorTitle ?? 'Temporary password failed',
              message: _forgotErrorMessage!,
            ),
          ],
          const SizedBox(height: 14),
          TextFormField(
            controller: _emailController,
            readOnly: true,
            showCursor: false,
            enableInteractiveSelection: false,
            decoration: _inputDecoration('Registered email').copyWith(
              errorText: _hasRegisteredEmail
                  ? _forgotFieldErrors['email']
                  : null,
              suffixIcon: const Icon(
                Icons.lock_outline,
                size: 20,
                color: Color(0xFF718096),
              ),
            ),
            validator: (value) {
              if (!_hasRegisteredEmail) {
                return 'Registered email is not available.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSendingTemporaryPassword || !_hasRegisteredEmail
                  ? null
                  : _sendTemporaryPassword,
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
              child: _isSendingTemporaryPassword
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Send temporary password',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangePasswordSection() {
    final hasAuthToken = _contextData?.hasAuthToken ?? true;

    return Form(
      key: _changeFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'After you receive the temporary password, use it as the current password below and set a new password.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF4A5568),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'If you still remember your current password, you can use it directly here.',
            style: TextStyle(fontSize: 12, color: Color(0xFF718096)),
          ),
          if (!hasAuthToken) ...[
            const SizedBox(height: 14),
            _buildErrorBanner(
              title: 'Session expired',
              message: 'Please login again before changing your password.',
            ),
          ],
          if (_changeErrorMessage != null) ...[
            const SizedBox(height: 14),
            _buildErrorBanner(
              title: _changeErrorTitle ?? 'Change password failed',
              message: _changeErrorMessage!,
            ),
          ],
          const SizedBox(height: 14),
          _buildPasswordField(
            controller: _currentPasswordController,
            label: 'Current or temporary password',
            obscureText: _obscureCurrentPassword,
            onToggleVisibility: () {
              setState(() {
                _obscureCurrentPassword = !_obscureCurrentPassword;
              });
            },
            onChanged: (_) => _clearChangeError('currentPassword'),
            errorText: _changeFieldErrors['currentPassword'],
            validator: (value) =>
                _requiredValidator(value, 'Current or temporary password'),
          ),
          const SizedBox(height: 12),
          _buildPasswordField(
            controller: _newPasswordController,
            label: 'New password',
            obscureText: _obscureNewPassword,
            onToggleVisibility: () {
              setState(() {
                _obscureNewPassword = !_obscureNewPassword;
              });
            },
            onChanged: (_) => _clearChangeError('newPassword'),
            errorText: _changeFieldErrors['newPassword'],
            validator: (value) {
              final requiredMessage = _requiredValidator(value, 'New password');
              if (requiredMessage != null) {
                return requiredMessage;
              }

              final trimmed = value!.trim();
              if (trimmed.length < 6) {
                return 'Password must be at least 6 characters.';
              }

              if (trimmed == _currentPasswordController.text.trim()) {
                return 'New password must be different from current password.';
              }

              return null;
            },
          ),
          const SizedBox(height: 12),
          _buildPasswordField(
            controller: _confirmPasswordController,
            label: 'Confirm new password',
            obscureText: _obscureConfirmPassword,
            onToggleVisibility: () {
              setState(() {
                _obscureConfirmPassword = !_obscureConfirmPassword;
              });
            },
            onChanged: (_) => _clearChangeError('confirmPassword'),
            errorText: _changeFieldErrors['confirmPassword'],
            validator: (value) {
              final requiredMessage = _requiredValidator(
                value,
                'Confirm new password',
              );
              if (requiredMessage != null) {
                return requiredMessage;
              }

              if (value!.trim() != _newPasswordController.text.trim()) {
                return 'Passwords do not match.';
              }

              return null;
            },
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: !hasAuthToken || _isChangingPassword
                  ? null
                  : _changePassword,
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
              child: _isChangingPassword
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Change password',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reset password is now handled in two steps using the authentication APIs.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF1F2937),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            (_contextData?.userType.trim().isNotEmpty ?? false)
                ? 'This will update the password for the signed-in ${_contextData!.userType} account.'
                : 'This will update the password for your signed-in account.',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF4A5568),
              height: 1.4,
            ),
          ),
          if (_isLoadingContext) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(minHeight: 3),
          ],
          if (_loadErrorMessage != null) ...[
            const SizedBox(height: 14),
            _buildErrorBanner(
              title: _loadErrorTitle ?? 'Password reset',
              message: _loadErrorMessage!,
              onRetry: () => _ensureContextLoaded(forceReload: true),
            ),
          ],
          const SizedBox(height: 18),
          _buildChangePasswordSection(),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
          ),
          _buildForgotPasswordSection(),
        ],
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
