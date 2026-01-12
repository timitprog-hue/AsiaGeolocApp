import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../core/api_client.dart';
import '../../core/auth_storage.dart';

import '../sales/sales_shell.dart';
import '../admin/admin_shell.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController(text: '');
  final _pass = TextEditingController(text: '');

  bool _loading = false;
  String? _error;

  // UI states (premium)
  bool _obscure = true;
  bool _remember = true;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final storage = AuthStorage();
      final api = ApiClient(storage);

      final res = await api.dio.post('/login', data: {
        'email': _email.text.trim(),
        'password': _pass.text,
      });

      // ===== ambil token =====
      final token = res.data['token'] as String?;
      if (token == null || token.isEmpty) {
        throw Exception('Token kosong');
      }
      await storage.saveToken(token);

      // ===== ambil role dari response login (tanpa perlu /me) =====
      final user = res.data['user'] as Map<String, dynamic>?;
      final role = (user?['role'] ?? 'sales').toString().toLowerCase();

      if (!mounted) return;

      if (role == 'admin') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminShell()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SalesShell()),
        );
      }
    } on DioException catch (e) {
      final data = e.response?.data;

      String msg = 'Login gagal';
      if (data is Map) {
        // Laravel ValidationException biasanya: { message, errors: { email: [...] } }
        final errors = data['errors'];
        if (errors is Map &&
            errors['email'] is List &&
            (errors['email'] as List).isNotEmpty) {
          msg = (errors['email'] as List).first.toString();
        } else if (data['message'] != null) {
          msg = data['message'].toString();
        }
      } else if (data != null) {
        msg = data.toString();
      }

      setState(() => _error = msg);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // ===== Background premium (gradient + glow) =====
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF070D1F),
                  const Color(0xFF0A0F1F),
                  cs.primary.withOpacity(0.20),
                ],
              ),
            ),
          ),
          Positioned(
            top: -120,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primary.withOpacity(0.18),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.secondary.withOpacity(0.12),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ===== Header =====
                      _BrandHeader(cs: cs),

                      const SizedBox(height: 18),

                      // ===== Card form =====
                      Container(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                        decoration: BoxDecoration(
                          color:
                              isDark ? Colors.white.withOpacity(0.06) : cs.surface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.10),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Masuk untuk mengakses dashboard monitoring.',
                              style: TextStyle(
                                color: (isDark ? Colors.white : cs.onSurface)
                                    .withOpacity(0.70),
                              ),
                            ),
                            const SizedBox(height: 16),

                            _PremiumField(
                              controller: _email,
                              label: 'Email',
                              hint: 'nama@company.com',
                              prefix: Icons.alternate_email_rounded,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 12),

                            _PremiumField(
                              controller: _pass,
                              label: 'Password',
                              hint: '••••••••',
                              prefix: Icons.lock_rounded,
                              obscureText: _obscure,
                              suffix: IconButton(
                                tooltip: _obscure ? 'Show' : 'Hide',
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            // remember + forgot
                            Row(
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () =>
                                      setState(() => _remember = !_remember),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 6),
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: _remember,
                                          onChanged: (v) => setState(
                                              () => _remember = v ?? true),
                                        ),
                                        Text(
                                          'Remember me',
                                          style: TextStyle(
                                            color: (isDark
                                                    ? Colors.white
                                                    : cs.onSurface)
                                                .withOpacity(0.75),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: _loading
                                      ? null
                                      : () {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Fitur "Forgot password" belum dibuat.'),
                                            ),
                                          );
                                        },
                                  child: const Text('Forgot?'),
                                ),
                              ],
                            ),

                            if (_error != null) ...[
                              const SizedBox(height: 6),
                              _ErrorPill(message: _error!),
                            ],

                            const SizedBox(height: 14),

                            // ===== Button login =====
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  backgroundColor: cs.primary,
                                  foregroundColor: cs.onPrimary,
                                ),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: _loading
                                      ? const SizedBox(
                                          key: ValueKey('loading'),
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Row(
                                          key: ValueKey('btn'),
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.login_rounded, size: 18),
                                            SizedBox(width: 8),
                                            Text(
                                              'Login',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w900),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            Text(
                              'By continuing, you agree to internal usage policy.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: (isDark ? Colors.white : cs.onSurface)
                                    .withOpacity(0.55),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ===== Footer small =====
                      Text(
                        'Asia Geoloc App • Secure Access',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.55),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  final ColorScheme cs;
  const _BrandHeader({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: cs.primary.withOpacity(0.14),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 18,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white, // 👈 background putih
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/logo/logo_ap.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Asia Geoloc App',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.white.withOpacity(0.95),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Monitoring laporan marketing lapangan secara realtime.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.70),
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _PremiumField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData prefix;
  final bool obscureText;
  final Widget? suffix;
  final TextInputType? keyboardType;

  const _PremiumField({
    required this.controller,
    required this.label,
    required this.prefix,
    this.hint,
    this.obscureText = false,
    this.suffix,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: (isDark ? Colors.white : cs.onSurface).withOpacity(0.85),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: TextStyle(
            color: isDark ? Colors.white.withOpacity(0.92) : cs.onSurface,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: (isDark ? Colors.white : cs.onSurface).withOpacity(0.45),
              fontWeight: FontWeight.w600,
            ),
            prefixIcon: Icon(prefix),
            suffixIcon: suffix,
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.06)
                : cs.surfaceContainerHighest.withOpacity(0.55),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  BorderSide(color: cs.primary.withOpacity(0.65), width: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorPill extends StatelessWidget {
  final String message;
  const _ErrorPill({required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.error.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.error.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: cs.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: cs.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
