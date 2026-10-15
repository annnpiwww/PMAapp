import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/theme_service.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../camera/screens/camera_capture_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identityCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _identityCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final identity = _identityCtrl.text.trim();
    final pass = _passwordCtrl.text.trim();
    if (identity.isEmpty || pass.isEmpty) {
      setState(() => _errorMessage = 'Username dan kata sandi wajib diisi.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await AuthRepository.instance.loginWithPassword(
      identity: identity,
      password: pass,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
        );
      } else {
        setState(() => _errorMessage = 'Username atau kata sandi salah');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, currentMode, _) {
        final isDark = ThemeService.isDarkMode(context);
        final bgScaffold = isDark ? AppColors.darkBackground : AppColors.background;
        final cardBg = isDark ? AppColors.darkSurface : Colors.white;
        final cardBorder = isDark ? AppColors.darkBorderMuted : AppColors.cardBorder;
        final titleColor = isDark ? AppColors.textDarkPrimary : AppColors.textPrimary;
        final subtitleColor = isDark ? AppColors.textDarkSecondary : AppColors.textSecondary;
        final labelColor = isDark ? AppColors.textDarkPrimary : AppColors.textSecondary;
        final inputBg = isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLow;
        final inputBorder = isDark ? AppColors.darkBorderMuted : AppColors.cardBorder;
        final inputTextColor = isDark ? AppColors.textDarkPrimary : AppColors.textPrimary;
        final hintColor = isDark ? AppColors.textDarkMuted : AppColors.textMuted;
        final iconColor = isDark ? AppColors.textDarkSecondary : AppColors.textMuted;

        return Scaffold(
          backgroundColor: bgScaffold,
          body: SafeArea(
            child: Stack(
              children: [
                // Top-right Theme Toggle with >=44dp touch target
                Positioned(
                  top: 8,
                  right: 16,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => ThemeService.toggleTheme(context),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                        child: Tooltip(
                          message: isDark ? 'Beralih ke mode terang' : 'Beralih ke mode gelap',
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: cardBorder, width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                                  size: 16,
                                  color: isDark ? AppColors.warning : AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isDark ? 'Terang' : 'Gelap',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 10),

                          // Logo Resmi Aplikasi BSS Parking
                          Center(
                            child: Container(
                              width: 88,
                              height: 88,
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                border: Border.all(
                                  color: AppColors.accent,
                                  width: 2.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.accent.withValues(alpha: isDark ? 0.35 : 0.22),
                                    blurRadius: 22,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'foto/splash_logo.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) => Container(
                                    color: AppColors.primary,
                                    child: const Center(
                                      child: Text(
                                        'PMA',
                                        style: TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          Text(
                            'PMA App',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Absen, Maintenance & Daily Task',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: subtitleColor,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Card Form Login
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: cardBorder, width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                    decoration: BoxDecoration(
                                      color: AppColors.danger.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.4), width: 1),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.danger),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: const TextStyle(
                                              fontFamily: 'PlusJakartaSans',
                                              fontSize: 12,
                                              color: AppColors.danger,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                ],

                                // Username Input
                                Text(
                                  'Username',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: labelColor,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _identityCtrl,
                                  keyboardType: TextInputType.text,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    color: inputTextColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Username',
                                    hintStyle: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      color: hintColor,
                                      fontSize: 13,
                                    ),
                                    filled: true,
                                    fillColor: inputBg,
                                    prefixIcon: Icon(Icons.person_outline_rounded, color: iconColor, size: 20),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: inputBorder),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: inputBorder),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(color: AppColors.accent, width: 1.8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // Password Input
                                Text(
                                  'Kata Sandi',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: labelColor,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _passwordCtrl,
                                  obscureText: _obscurePassword,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    color: inputTextColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  onSubmitted: (_) => _handleLogin(),
                                  decoration: InputDecoration(
                                    hintText: 'Katasandi',
                                    hintStyle: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      color: hintColor,
                                      fontSize: 13,
                                    ),
                                    filled: true,
                                    fillColor: inputBg,
                                    prefixIcon: Icon(Icons.lock_outline_rounded, color: iconColor, size: 20),
                                    suffixIcon: IconButton(
                                      tooltip: _obscurePassword ? 'Tampilkan kata sandi' : 'Sembunyikan kata sandi',
                                      icon: Icon(
                                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                        color: iconColor,
                                        size: 20,
                                      ),
                                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: inputBorder),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: inputBorder),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(color: AppColors.accent, width: 1.8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                                  ),
                                ),
                                const SizedBox(height: 26),

                                // Tombol Masuk
                                Semantics(
                                  label: 'Tombol masuk akun',
                                  button: true,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.accent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 15),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      elevation: 0,
                                      shadowColor: Colors.transparent,
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                                          )
                                        : const Text(
                                            'Login',
                                            style: TextStyle(
                                              fontFamily: 'PlusJakartaSans',
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Footer
                          Center(
                            child: Text(
                              'PMAapp powered by annnpii',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: subtitleColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


}
