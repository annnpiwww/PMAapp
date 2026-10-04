import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/ai_vision_config.dart';
import '../../../data/services/ai_vision_service.dart';

class AiVisionSettingsScreen extends StatefulWidget {
  const AiVisionSettingsScreen({super.key});

  @override
  State<AiVisionSettingsScreen> createState() => _AiVisionSettingsScreenState();
}

class _AiVisionSettingsScreenState extends State<AiVisionSettingsScreen> {
  late AiVisionConfig _config;

  late TextEditingController _apiKeyController;
  late TextEditingController _baseUrlController;
  late TextEditingController _modelController;

  bool _obscureApiKey = true;
  bool _isTesting = false;
  AiConnectionTestResult? _testResult;

  @override
  void initState() {
    super.initState();
    _config = AiVisionService.getConfig();
    _apiKeyController = TextEditingController(text: _config.apiKey);
    _baseUrlController = TextEditingController(text: _config.baseUrl);
    _modelController = TextEditingController(text: _config.modelName);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _handleTestConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final testConfig = _config.copyWith(
      apiKey: _apiKeyController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      modelName: _modelController.text.trim(),
    );

    final result = await AiVisionService.testConnection(testConfig);

    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _testResult = result;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.isSuccess ? AppColors.success : AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleSave() async {
    final updated = _config.copyWith(
      apiKey: _apiKeyController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      modelName: _modelController.text.trim(),
    );

    await AiVisionService.updateConfig(updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengaturan AI Vision tersimpan!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  void _handleResetDefault() {
    final def = AiVisionConfig.defaultConfig();
    setState(() {
      _config = def;
      _apiKeyController.text = def.apiKey;
      _baseUrlController.text = def.baseUrl;
      _modelController.text = def.modelName;
      _testResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pengaturan AI Vision'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded),
            tooltip: 'Simpan',
            onPressed: _handleSave,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- CARD 1: PROVIDER & CREDENTIALS ---
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.hub_outlined, color: AppColors.primary, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Provider & Endpoint AI Vision',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                                ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<AiProviderType>(
                            initialValue: _config.provider,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Pilih AI Provider',
                              isDense: true,
                            ),
                            items: AiProviderType.values.map((p) {
                              return DropdownMenuItem(
                                value: p,
                                child: Text(
                                  p.displayName,
                                  style: const TextStyle(fontSize: 12.5),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _config = _config.copyWith(provider: val);
                                  if (_baseUrlController.text.trim().isEmpty) {
                                    _baseUrlController.text = val.defaultBaseUrl;
                                  }
                                  if (_modelController.text.trim().isEmpty) {
                                    _modelController.text = val.defaultModel;
                                  }
                                });
                              }
                            },
                                ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _baseUrlController,
                            decoration: const InputDecoration(
                              labelText: 'Base URL Endpoint',
                              hintText: 'https://generativelanguage.googleapis.com/v1beta/openai',
                              isDense: true,
                            ),
                                ),
                          const SizedBox(height: 12),
                          TextField(
                      controller: _modelController,
                      decoration: const InputDecoration(
                              labelText: 'Model ID',
                              hintText: 'gemini-3.1-flash-lite',
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 6),
                            Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              ActionChip(
                                avatar: const Icon(Icons.flash_on, size: 14),
                                label: const Text('Gemini 3.1 Flash Lite',
                                  style: TextStyle(fontSize: 11)),
                                onPressed: () {
                                  setState(() {
                                    _modelController.text = 'gemini-3.1-flash-lite';
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _apiKeyController,
                            obscureText: _obscureApiKey,
                            decoration: InputDecoration(
                              labelText: 'API Key Bearer Token (Google AI Studio)',
                              hintText: 'AQ.Ab8... / AIzaSy...',
                              helperText: 'Dapatkan token gratis dari aistudio.google.com',
                              helperStyle: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              isDense: true,
                              suffixIcon: IconButton(
                                tooltip: _obscureApiKey ? 'Tampilkan API Key' : 'Sembunyikan API Key',
                                icon: Icon(
                                  _obscureApiKey
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                  size: 18,
                                ),
                                onPressed: () {
                                  setState(
                                    () => _obscureApiKey = !_obscureApiKey);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // --- CARD 2: TEST CONNECTION ---
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Uji Latensi & Konektivitas',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Timeout: 25s/model (budget 35s), auto-fallback',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: _isTesting ? null : _handleTestConnection,
                                icon: _isTesting
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.network_check_rounded, size: 16),
                                label: Text(_isTesting ? 'Menguji...' : 'Uji Koneksi AI'),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(120, 36),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                ),
                              ),
                            ],
                                ),
                          if (_testResult != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _testResult!.isSuccess
                                    ? AppColors.successLight
                                    : AppColors.dangerLight,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _testResult!.isSuccess
                                      ? AppColors.success
                                      : AppColors.danger,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    _testResult!.isSuccess
                                        ? Icons.check_circle_rounded
                                        : Icons.cancel_rounded,
                                    color: _testResult!.isSuccess
                                        ? AppColors.success
                                        : AppColors.danger,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _testResult!.isSuccess
                                              ? 'ONLINE (${_testResult!.latencyMs} ms)'
                                              : 'KONEKSI GAGAL',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: _testResult!.isSuccess
                                                ? AppColors.success
                                                : AppColors.danger,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _testResult!.message,
                                          style: const TextStyle(fontSize: 11.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                            ),
                          ),
                  ),

                  const SizedBox(height: 14),

                  // --- CARD 3: CONFIDENCE THRESHOLD SLIDER ---
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'Ambang Batas Kepercayaan (Confidence)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${(_config.confidenceThreshold * 100).toInt()}%',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                                ),
                          const SizedBox(height: 4),
                          const Text(
                            'Skor minimal bagi AI untuk meloloskan foto secara otomatis.',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                          Slider(
                            value: _config.confidenceThreshold,
                            min: 0.5,
                            max: 1.0,
                            divisions: 10,
                            label: '${(_config.confidenceThreshold * 100).toInt()}%',
                            activeColor: AppColors.primary,
                            onChanged: (val) {
                              setState(() {
                                _config = _config.copyWith(confidenceThreshold: val);
                              });
                            },
                                ),
                        ],
                            ),
                          ),
                  ),

                  const SizedBox(height: 14),

                  // --- CARD 4: INSPECTION TOGGLES ---
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fitur Pemeriksaan SOP AI',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                                ),
                          const SizedBox(height: 10),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Deteksi Kerapian Seragam & Grooming',
                                style: TextStyle(fontSize: 12.5)),
                            value: _config.enableGroomingCheck,
                            activeThumbColor: AppColors.primary,
                            onChanged: (val) => setState(() => _config =
                                _config.copyWith(enableGroomingCheck: val)),
                                ),
                          const Divider(height: 1),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Deteksi ID Card / Name Tag',
                                style: TextStyle(fontSize: 12.5)),
                            value: _config.enableIdCardDetection,
                            activeThumbColor: AppColors.primary,
                            onChanged: (val) => setState(() => _config =
                                _config.copyWith(enableIdCardDetection: val)),
                                ),
                          const Divider(height: 1),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Pemeriksaan Barisan & Sikap Briefing',
                                style: TextStyle(fontSize: 12.5)),
                            value: _config.enableFormationCheck,
                            activeThumbColor: AppColors.primary,
                            onChanged: (val) => setState(() => _config =
                                _config.copyWith(enableFormationCheck: val)),
                                ),
                          const Divider(height: 1),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Deteksi Kebersihan Pos & Bebas Halangan',
                                style: TextStyle(fontSize: 12.5)),
                            value: _config.enableCleanlinessCheck,
                            activeThumbColor: AppColors.primary,
                            onChanged: (val) => setState(() => _config =
                                _config.copyWith(enableCleanlinessCheck: val)),
                                ),
                        ],
                            ),
                          ),
                  ),

                  const SizedBox(height: 20),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _handleResetDefault,
                          child: const Text('Reset Default'),
                              ),
                            ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _handleSave,
                          child: const Text('Simpan Pengaturan'),
                              ),
                            ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
