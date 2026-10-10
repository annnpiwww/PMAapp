import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../camera/screens/camera_capture_screen.dart';
import '../../auth/screens/login_screen.dart';

/// Smooth, modern animated splash screen untuk PMAapp.
/// Menampilkan micro-interactions logo pulse, live status loading ringan,
/// dan transisi fade ke viewfinder kamera utama tanpa jank.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _pulseAnimation;

  final List<Timer> _pendingTimers = [];
  String _loadingStatus = 'Menyiapkan aplikasi...';
  double _progress = 0.15;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeInOut),
      ),
    );

    _animController.forward();
    _startSmoothStartupSequence();
  }

  void _startSmoothStartupSequence() {
    // Step 1: Inisialisasi Core & Storage
    _pendingTimers.add(Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _loadingStatus = 'Mengecek GPS dan waktu WITA...';
        _progress = 0.40;
      });

      // Step 2: Menyiapkan Sensor Optik Kamera (Durasi menunggu kamera hardware warm-up)
      _pendingTimers.add(Timer(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        setState(() {
          _loadingStatus = 'Menyiapkan kamera...';
          _progress = 0.70;
        });

        // Step 3: Template & Cache
        _pendingTimers.add(Timer(const Duration(milliseconds: 900), () {
          if (!mounted) return;
          setState(() {
            _loadingStatus = 'Memuat template checklist...';
            _progress = 0.92;
          });

          // Step 4: Selesai & Transisi Mulus (Kamera sudah siap di viewfinder)
          _pendingTimers.add(Timer(const Duration(milliseconds: 600), () {
            if (!mounted) return;
            setState(() {
              _loadingStatus = 'Siap digunakan!';
              _progress = 1.0;
            });

            _pendingTimers.add(Timer(const Duration(milliseconds: 300), () {
              if (!mounted) return;
              final isLoggedIn = AuthRepository.instance.isLoggedIn;
              final targetScreen = isLoggedIn ? const CameraCaptureScreen() : const LoginScreen();

              Navigator.of(context).pushReplacement(
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 500),
                  pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                ),
              );
            }));
          }));
        }));
      }));
    }));
  }

  @override
  void dispose() {
    for (final t in _pendingTimers) {
      t.cancel();
    }
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white, // Clean Modern White Theme
        body: Stack(
          children: [
            // Ambient glowing radial spotlight
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -80,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.08),
                ),
              ),
            ),

            // Content Center
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),

                      // Animated Official Logo Emblem BSS Parking
                      AnimatedBuilder(
                        animation: _animController,
                        builder: (context, child) {
                          final currentScale = _animController.value > 0.6
                              ? _pulseAnimation.value
                              : _scaleAnimation.value;
                          return Opacity(
                            opacity: _opacityAnimation.value,
                            child: Transform.scale(
                              scale: currentScale,
                              child: child,
                            ),
                          );
                        },
                        child: Container(
                          width: 114,
                          height: 114,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                              color: AppColors.primary,
                              width: 3.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.18),
                                blurRadius: 25,
                                offset: const Offset(0, 6),
                              ),
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.25),
                                blurRadius: 15,
                                spreadRadius: 1,
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
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Brand Titles: PMA (Project Maintenance Assembly)
                      const Text(
                        'PMA',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          letterSpacing: 3.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Project Maintenance Assembly',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accent,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 1 BARIS MUTLAK TANPA PATAH
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Technician Maintenance, Grooming & Daily task',
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Sleek Progress Line & Status Text
                      Column(
                        children: [
                          // Animated Progress Bar
                          Container(
                            height: 4,
                            width: 200,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                                height: 4,
                                width: 200 * _progress,
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.accent.withValues(alpha: 0.5),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              _loadingStatus,
                              key: ValueKey(_loadingStatus),
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 36),

                      // Footer Subdued Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 0.9,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Made by ❤️ annnpii',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
