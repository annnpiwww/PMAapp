import 'package:flutter/material.dart';
import '../../../core/constants/tiket_colors.dart';
import '../../../core/services/theme_service.dart';
import '../../../core/widgets/tiket/status_marker.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../camera/screens/camera_capture_screen.dart';

class TicketCardPerforationPainter extends CustomPainter {
  final Color bandColor;
  final Color dashColor;

  const TicketCardPerforationPainter({
    required this.bandColor,
    required this.dashColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2.0;

    final linePaint = Paint()
      ..color = dashColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashGap = 6.0;
    const inset = 24.0;
    final startX = inset;
    final endX = size.width - inset;

    double currentX = startX;
    while (currentX < endX) {
      final nextX = (currentX + dashWidth).clamp(startX, endX);
      canvas.drawLine(Offset(currentX, centerY), Offset(nextX, centerY), linePaint);
      currentX += dashWidth + dashGap;
    }

    final notchPaint = Paint()
      ..color = bandColor
      ..style = PaintingStyle.fill;

    const notchRadius = 12.0;
    canvas.drawCircle(Offset(0, centerY), notchRadius, notchPaint);
    canvas.drawCircle(Offset(size.width, centerY), notchRadius, notchPaint);
  }

  @override
  bool shouldRepaint(covariant TicketCardPerforationPainter oldDelegate) =>
      oldDelegate.bandColor != bandColor || oldDelegate.dashColor != dashColor;
}

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('foto/splash_logo.png'), context);
  }

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
        final colors = TiketColors.of(context);
        final isDark = ThemeService.isDarkMode(context);
        final cardBg = isDark ? colors.dialog : colors.canvas;

        return Scaffold(
          backgroundColor: colors.band,
          body: SafeArea(
            child: Stack(
              children: [
                // Top-right Theme Toggle
                Positioned(
                  top: 8,
                  right: 16,
                  child: Semantics(
                    button: true,
                    label: isDark ? 'Beralih ke mode terang' : 'Beralih ke mode gelap',
                    child: Tooltip(
                      message: isDark ? 'Beralih ke mode terang' : 'Beralih ke mode gelap',
                      child: Material(
                        color: colors.bandRaise,
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: colors.bandLine,
                            width: 1.5,
                          ),
                        ),
                        child: InkWell(
                          customBorder: const StadiumBorder(),
                          splashColor: colors.primaryPressed,
                          onTap: () => ThemeService.toggleTheme(context),
                          child: SizedBox(
                            height: 44,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                                    size: 16,
                                    color: colors.onBand,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isDark ? 'Terang' : 'Gelap',
                                    style: TextStyle(
                                      fontFamily: TiketType.fontFamily,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: colors.onBand,
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
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24.0),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 600),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(height: 36),
                                    // Ticket Card
                                    Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 20),
                                      decoration: BoxDecoration(
                                        color: cardBg,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: isDark
                                            ? null
                                            : [
                                                BoxShadow(
                                                  color: colors.black.withValues(alpha: 0.15),
                                                  blurRadius: 20,
                                                  offset: const Offset(0, 8),
                                                ),
                                              ],
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          // Card Stub
                                          Padding(
                                            padding: const EdgeInsets.all(24.0),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 64,
                                                  height: 64,
                                                  decoration: const BoxDecoration(
                                                    shape: BoxShape.circle,
                                                  ),
                                                  clipBehavior: Clip.antiAlias,
                                                  child: Image.asset(
                                                    'foto/splash_logo.png',
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (ctx, err, stack) => Container(
                                                      color: colors.primary,
                                                      child: Center(
                                                        child: Text(
                                                          'PMA',
                                                          style: TextStyle(
                                                            fontFamily: TiketType.fontFamily,
                                                            fontSize: 18,
                                                            fontWeight: FontWeight.w900,
                                                            color: colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'PMApp',
                                                        style: TextStyle(
                                                          fontFamily: TiketType.fontFamily,
                                                          fontSize: 26,
                                                          fontWeight: FontWeight.w800,
                                                          color: colors.ink,
                                                          letterSpacing: -0.6,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'Absen, Maintenance & Daily Task',
                                                        style: TextStyle(
                                                          fontFamily: TiketType.fontFamily,
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w500,
                                                          color: colors.body,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Perforation under the stub
                                          ExcludeSemantics(
                                            child: SizedBox(
                                              height: 24,
                                              child: CustomPaint(
                                                painter: TicketCardPerforationPainter(
                                                  bandColor: colors.band,
                                                  dashColor: isDark
                                                      ? colors.bandLine
                                                      : colors.mute.withValues(alpha: 0.6),
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Form below perforation
                                          Padding(
                                            padding: const EdgeInsets.all(24.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: [
                                                if (_errorMessage != null) ...[
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                    decoration: BoxDecoration(
                                                      color: colors.dangerTint,
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        const StatusMarker(
                                                          status: TiketStatus.danger,
                                                          size: 16,
                                                        ),
                                                        const SizedBox(width: 10),
                                                        Expanded(
                                                          child: Text(
                                                            _errorMessage!,
                                                            style: TextStyle(
                                                              fontFamily: TiketType.fontFamily,
                                                              fontSize: 13,
                                                              fontWeight: FontWeight.w600,
                                                              color: colors.danger,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 18),
                                                ],
                                                // Username Field
                                                Text(
                                                  'Username',
                                                  style: TextStyle(
                                                    fontFamily: TiketType.fontFamily,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                    color: colors.ink,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                SizedBox(
                                                  height: 52,
                                                  child: TextField(
                                                    controller: _identityCtrl,
                                                    keyboardType: TextInputType.text,
                                                    autocorrect: false,
                                                    enableSuggestions: false,
                                                    style: TextStyle(
                                                      fontFamily: TiketType.fontFamily,
                                                      color: colors.ink,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                    decoration: InputDecoration(
                                                      hintText: 'Username',
                                                      hintStyle: TextStyle(
                                                        fontFamily: TiketType.fontFamily,
                                                        color: colors.body,
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w400,
                                                      ),
                                                      filled: true,
                                                      fillColor: colors.soft,
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                                      border: UnderlineInputBorder(
                                                        borderRadius: BorderRadius.zero,
                                                        borderSide: BorderSide(color: colors.body, width: 2.0),
                                                      ),
                                                      enabledBorder: UnderlineInputBorder(
                                                        borderRadius: BorderRadius.zero,
                                                        borderSide: BorderSide(color: colors.body, width: 2.0),
                                                      ),
                                                      focusedBorder: UnderlineInputBorder(
                                                        borderRadius: BorderRadius.zero,
                                                        borderSide: BorderSide(color: colors.primary, width: 2.0),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 18),
                                                // Password Field
                                                Text(
                                                  'Kata Sandi',
                                                  style: TextStyle(
                                                    fontFamily: TiketType.fontFamily,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                    color: colors.ink,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                SizedBox(
                                                  height: 52,
                                                  child: TextField(
                                                    controller: _passwordCtrl,
                                                    obscureText: _obscurePassword,
                                                    autocorrect: false,
                                                    enableSuggestions: false,
                                                    style: TextStyle(
                                                      fontFamily: TiketType.fontFamily,
                                                      color: colors.ink,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                    onSubmitted: (_) => _handleLogin(),
                                                    decoration: InputDecoration(
                                                      hintText: 'Katasandi',
                                                      hintStyle: TextStyle(
                                                        fontFamily: TiketType.fontFamily,
                                                        color: colors.body,
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w400,
                                                      ),
                                                      filled: true,
                                                      fillColor: colors.soft,
                                                      suffixIcon: SizedBox(
                                                        width: 48,
                                                        height: 48,
                                                        child: IconButton(
                                                          tooltip: _obscurePassword ? 'Tampilkan kata sandi' : 'Sembunyikan kata sandi',
                                                          icon: Icon(
                                                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                                            color: colors.body,
                                                            size: 20,
                                                          ),
                                                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                                        ),
                                                      ),
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                                      border: UnderlineInputBorder(
                                                        borderRadius: BorderRadius.zero,
                                                        borderSide: BorderSide(color: colors.body, width: 2.0),
                                                      ),
                                                      enabledBorder: UnderlineInputBorder(
                                                        borderRadius: BorderRadius.zero,
                                                        borderSide: BorderSide(color: colors.body, width: 2.0),
                                                      ),
                                                      focusedBorder: UnderlineInputBorder(
                                                        borderRadius: BorderRadius.zero,
                                                        borderSide: BorderSide(color: colors.primary, width: 2.0),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 26),
                                                // Login CTA Button
                                                Semantics(
                                                  label: 'Tombol masuk akun',
                                                  button: true,
                                                  child: SizedBox(
                                                    height: 52,
                                                    child: ElevatedButton(
                                                      onPressed: _isLoading ? null : _handleLogin,
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: isDark ? colors.white : colors.primary,
                                                        foregroundColor: isDark ? colors.black : colors.onPrimary,
                                                        disabledBackgroundColor: colors.soft,
                                                        disabledForegroundColor: colors.body,
                                                        elevation: 0,
                                                        shape: const StadiumBorder(),
                                                      ),
                                                      child: _isLoading
                                                          ? SizedBox(
                                                              width: 22,
                                                              height: 22,
                                                              child: CircularProgressIndicator(
                                                                strokeWidth: 2.2,
                                                                color: isDark ? colors.black : colors.onPrimary,
                                                              ),
                                                            )
                                                          : const Text(
                                                              'Login',
                                                              style: TextStyle(
                                                                fontFamily: TiketType.fontFamily,
                                                                fontSize: 16,
                                                                fontWeight: FontWeight.w700,
                                                                letterSpacing: 0.2,
                                                              ),
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
                                    const SizedBox(height: 28),
                                    // Footer
                                    Center(
                                      child: Text(
                                        'PMAapp powered by annnpii',
                                        style: TextStyle(
                                          fontFamily: TiketType.fontFamily,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: colors.bandCaption,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
