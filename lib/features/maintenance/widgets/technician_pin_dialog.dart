import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/services/storage_service.dart';

class TechnicianPinDialog extends StatefulWidget {
  final VoidCallback onPinVerified;
  final String? title;
  final String? subtitle;

  const TechnicianPinDialog({
    super.key,
    required this.onPinVerified,
    this.title,
    this.subtitle,
  });
  @override
  State<TechnicianPinDialog> createState() => _TechnicianPinDialogState();
}

class _TechnicianPinDialogState extends State<TechnicianPinDialog> {
  final TextEditingController _pinController = TextEditingController();
  bool _isError = false;
  bool _isChecking = false;
  String _errorMessage = '';

  Future<void> _verifyPin() async {
    if (_isChecking) return;
    setState(() {
      _isChecking = true;
      _isError = false;
    });
    final result =
        await StorageService.verifyTechnicianPin(_pinController.text);
    if (!mounted) return;
    if (result.ok) {
      Navigator.of(context).pop();
      widget.onPinVerified();
    } else {
      setState(() {
        _isChecking = false;
        _isError = true;
        _errorMessage = result.message;
        _pinController.clear();
      });
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(22),
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_person_rounded,
                color: AppColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.title ?? 'Akses Khusus Teknisi',
              style: const TextStyle(fontFamily: 'PlusJakartaSans', 
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.subtitle ??
                  'Masukkan PIN teknisi untuk membuka menu pemeliharaan perangkat.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              textAlign: TextAlign.center,
              autofocus: true,
              maxLength: 6,
              style: TextStyle(fontFamily: 'PlusJakartaSans', 
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: '••••••',
                hintStyle: const TextStyle(letterSpacing: 8),
                errorText: _isError ? _errorMessage : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _isError ? AppColors.danger : AppColors.cardBorder,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.8,
                  ),
                ),
              ),
              onSubmitted: (_) => _verifyPin(),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isChecking ? null : _verifyPin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isChecking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Buka Fitur',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
