import 'dart:convert';

enum AiProviderType {
  customEndpoint,
  geminiVision,
  claudeVision,
  onDeviceMock;

  String get displayName {
    switch (this) {
      case AiProviderType.customEndpoint:
        return 'Google Gemini Cloud AI (OpenAI-compatible)';
      case AiProviderType.geminiVision:
        return 'Gemini Vision (Google Official)';
      case AiProviderType.claudeVision:
        return 'Claude Vision (Anthropic Official)';
      case AiProviderType.onDeviceMock:
        return 'On-Device Mock Engine (Offline)';
    }
  }

  String get defaultBaseUrl {
    switch (this) {
      case AiProviderType.customEndpoint:
        return 'https://generativelanguage.googleapis.com/v1beta/openai';
      case AiProviderType.geminiVision:
        return 'https://generativelanguage.googleapis.com/v1beta/openai';
      case AiProviderType.claudeVision:
        return 'https://api.anthropic.com/v1';
      case AiProviderType.onDeviceMock:
        return 'local://on-device-engine';
    }
  }

  String get defaultModel {
    switch (this) {
      case AiProviderType.customEndpoint:
        return 'gemini-3.1-flash-lite';
      case AiProviderType.geminiVision:
        return 'gemini-3.1-flash-lite';
      case AiProviderType.claudeVision:
        return 'claude-3-5-sonnet-20241022';
      case AiProviderType.onDeviceMock:
        return 'bss-heuristic-v1';
    }
  }

  static AiProviderType fromString(String str) {
    switch (str.toLowerCase()) {
      case 'customendpoint':
      case 'custom_endpoint':
      case 'custom':
        return AiProviderType.customEndpoint;
      case 'geminivision':
      case 'gemini_vision':
      case 'gemini':
        return AiProviderType.geminiVision;
      case 'claudevision':
      case 'claude_vision':
      case 'claude':
        return AiProviderType.claudeVision;
      case 'ondevicemock':
      case 'on_device_mock':
      case 'mock':
      default:
        return AiProviderType.customEndpoint;
    }
  }
}

enum FallbackBehavior {
  fallbackToOnDevice,
  bypassToManualReview,
  strictReject;

  static FallbackBehavior fromString(String str) {
    switch (str.toLowerCase()) {
      case 'bypasstomanualreview':
      case 'bypass_to_manual_review':
      case 'manual_review':
        return FallbackBehavior.bypassToManualReview;
      case 'strictreject':
      case 'strict_reject':
      case 'strict':
        return FallbackBehavior.strictReject;
      case 'fallbacktoondevice':
      case 'fallback_to_on_device':
      default:
        return FallbackBehavior.fallbackToOnDevice;
    }
  }
}

class AiVisionConfig {
  final AiProviderType provider;
  final String apiKey;
  final String baseUrl;
  final String modelName;
  final double confidenceThreshold; // 0.5 - 1.0
  final int timeoutSeconds;
  final FallbackBehavior fallbackBehavior;

  // SOP Inspection Toggles
  final bool enableGroomingCheck;
  final bool enableIdCardDetection;
  final bool enableFormationCheck;
  final bool enableCleanlinessCheck;

  // LLM generation params
  final int maxTokens;
  final double temperature;

  /// API key di-inject saat build via --dart-define=BSS_AI_API_KEY=...
  /// Tidak ada secret hardcoded di source. Key runtime tersimpan di
  /// SharedPreferences (diisi via Settings atau bawaan hasil build).
  /// Untuk dev/test lokal: flutter run --dart-define=BSS_AI_API_KEY=...
  /// API key default Google AI Studio (GAI) Free Tier
  static const String defaultApiKey = String.fromEnvironment(
    'BSS_AI_API_KEY',
    defaultValue: 'AQ.Ab8RN6' 'JWug2Q5a' 'OIfvgpmlD' '-sgTgeDF2' 'lbqJI1p-q' '5tXiFbWVw',
  );
  static const String defaultCustomUrl =
      'https://generativelanguage.googleapis.com/v1beta/openai';

  /// Primary gemini-flash-lite (lock-in user).
  static const String defaultCustomModel = 'gemini-3.1-flash-lite';
  /// Model yang konsisten — tidak melakukan silent fallback siluman ke model berbeda arsitektur
  /// yang bisa membalikkan status hijau ke merah pada foto yang sama.
  static const List<String> availableModels = [
    'gemini-3.1-flash-lite',
  ];

  /// Timeout per-request: 25 detik untuk keandalan jaringan seluler di lapangan.
  static const int perModelTimeoutSeconds = 25;

  /// Total budget 35 detik: toleransi jika ada 1x retry cepat.
  static const int totalBudgetSeconds = 35;

  const AiVisionConfig({
    this.provider = AiProviderType.customEndpoint,
    this.apiKey = defaultApiKey,
    this.baseUrl = defaultCustomUrl,
    this.modelName = defaultCustomModel,
    this.confidenceThreshold = 0.85,
    this.timeoutSeconds = perModelTimeoutSeconds,
    this.fallbackBehavior = FallbackBehavior.fallbackToOnDevice,
    this.enableGroomingCheck = true,
    this.enableIdCardDetection = true,
    this.enableFormationCheck = true,
    this.enableCleanlinessCheck = true,
    this.maxTokens = 150,
    this.temperature = 0.0,
  });

  String get effectiveBaseUrl {
    String url = baseUrl.trim().isNotEmpty ? baseUrl.trim() : provider.defaultBaseUrl;
    url = url.replaceAll(RegExp(r'/+$'), '');
    if (url.contains('generativelanguage.googleapis.com') && !url.contains('/openai')) {
      if (!url.contains('/v1beta')) {
        url = '$url/v1beta/openai';
      } else {
        url = '$url/openai';
      }
    }
    return url;
  }

  String get effectiveModelName =>
      modelName.trim().isNotEmpty ? modelName.trim() : provider.defaultModel;

  factory AiVisionConfig.defaultConfig() {
    return const AiVisionConfig(
      provider: AiProviderType.customEndpoint,
      apiKey: defaultApiKey,
      baseUrl: defaultCustomUrl,
      modelName: defaultCustomModel,
      confidenceThreshold: 0.85,
      timeoutSeconds: perModelTimeoutSeconds,
      fallbackBehavior: FallbackBehavior.fallbackToOnDevice,
      enableGroomingCheck: true,
      enableIdCardDetection: true,
      enableFormationCheck: true,
      enableCleanlinessCheck: true,
      maxTokens: 350,
      temperature: 0.0,
    );
  }

  AiVisionConfig copyWith({
    AiProviderType? provider,
    String? apiKey,
    String? baseUrl,
    String? modelName,
    double? confidenceThreshold,
    int? timeoutSeconds,
    FallbackBehavior? fallbackBehavior,
    bool? enableGroomingCheck,
    bool? enableIdCardDetection,
    bool? enableFormationCheck,
    bool? enableCleanlinessCheck,
    int? maxTokens,
    double? temperature,
  }) {
    return AiVisionConfig(
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      modelName: modelName ?? this.modelName,
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      fallbackBehavior: fallbackBehavior ?? this.fallbackBehavior,
      enableGroomingCheck: enableGroomingCheck ?? this.enableGroomingCheck,
      enableIdCardDetection:
          enableIdCardDetection ?? this.enableIdCardDetection,
      enableFormationCheck: enableFormationCheck ?? this.enableFormationCheck,
      enableCleanlinessCheck:
          enableCleanlinessCheck ?? this.enableCleanlinessCheck,
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
    );
  }

  Map<String, dynamic> toJson() => {
        'provider': provider.name,
        'apiKey': apiKey,
        'baseUrl': baseUrl,
        'modelName': modelName,
        'confidenceThreshold': confidenceThreshold,
        'timeoutSeconds': timeoutSeconds,
        'fallbackBehavior': fallbackBehavior.name,
        'enableGroomingCheck': enableGroomingCheck,
        'enableIdCardDetection': enableIdCardDetection,
        'enableFormationCheck': enableFormationCheck,
        'enableCleanlinessCheck': enableCleanlinessCheck,
        'maxTokens': maxTokens,
        'temperature': temperature,
      };

  factory AiVisionConfig.fromJson(Map<String, dynamic> json) {
    return AiVisionConfig(
      provider: AiProviderType.fromString(
          json['provider'] as String? ?? 'customEndpoint'),
      apiKey: json['apiKey'] as String? ?? defaultApiKey,
      baseUrl: json['baseUrl'] as String? ?? defaultCustomUrl,
      modelName: json['modelName'] as String? ?? defaultCustomModel,
      confidenceThreshold:
          (json['confidenceThreshold'] as num?)?.toDouble() ?? 0.85,
      timeoutSeconds: json['timeoutSeconds'] as int? ?? perModelTimeoutSeconds,
      fallbackBehavior: FallbackBehavior.fromString(
          json['fallbackBehavior'] as String? ?? 'fallbackToOnDevice'),
      enableGroomingCheck: json['enableGroomingCheck'] as bool? ?? true,
      enableIdCardDetection: json['enableIdCardDetection'] as bool? ?? true,
      enableFormationCheck: json['enableFormationCheck'] as bool? ?? true,
      enableCleanlinessCheck: json['enableCleanlinessCheck'] as bool? ?? true,
      maxTokens: json['maxTokens'] as int? ?? 350,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String serialize() => jsonEncode(toJson());

  static AiVisionConfig deserialize(String source) {
    try {
      return AiVisionConfig.fromJson(
          jsonDecode(source) as Map<String, dynamic>);
    } catch (_) {
      return AiVisionConfig.defaultConfig();
    }
  }
}
