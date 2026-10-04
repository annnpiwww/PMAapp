import 'package:flutter/foundation.dart';
import '../models/submission_model.dart';
import '../services/storage_service.dart';

class SubmissionRepository extends ChangeNotifier {
  static final SubmissionRepository instance = SubmissionRepository._internal();
  SubmissionRepository._internal();

  List<SubmissionModel> _submissions = [];
  List<SubmissionModel> get submissions => List.unmodifiable(_submissions);

  Future<void> init() async {
    final saved = StorageService.getSubmissions();
    if (saved != null) {
      _submissions = saved;
    } else {
      _submissions = [];
      await StorageService.saveSubmissions(_submissions);
    }
    notifyListeners();
  }

  Future<void> clearAll() async {
    _submissions = [];
    await StorageService.saveSubmissions(_submissions);
    notifyListeners();
  }

  Future<void> deleteSubmission(String id) async {
    _submissions.removeWhere((s) => s.id == id);
    await StorageService.saveSubmissions(_submissions);
    notifyListeners();
  }

  Future<void> addSubmission(SubmissionModel submission) async {
    _submissions.insert(0, submission);
    if (_submissions.length > StorageService.maxStoredSubmissions) {
      _submissions = _submissions.sublist(0, StorageService.maxStoredSubmissions);
    }
    await StorageService.saveSubmissions(_submissions);
    notifyListeners();
  }

  Future<void> overrideSubmissionStatus({
    required String submissionId,
    required VerificationStatus newStatus,
    required String note,
    required String supervisorName,
  }) async {
    final index = _submissions.indexWhere((s) => s.id == submissionId);
    if (index != -1) {
      final old = _submissions[index];
      _submissions[index] = old.copyWith(
        status: newStatus,
        overrideNote: note,
        overriddenBy: supervisorName,
      );
      await StorageService.saveSubmissions(_submissions);
      notifyListeners();
    }
  }

  List<SubmissionModel> filter({
    VerificationStatus? status,
    String? templateId,
    String? query,
  }) {
    return _submissions.where((sub) {
      if (status != null && sub.status != status) return false;
      if (templateId != null && templateId.isNotEmpty && sub.templateId != templateId) return false;
      if (query != null && query.trim().isNotEmpty) {
        final q = query.toLowerCase();
        final matchCode = sub.kodeVerifikasi.toLowerCase().contains(q);
        final matchUser = sub.userName.toLowerCase().contains(q);
        final matchTemplate = sub.templateName.toLowerCase().contains(q);
        final matchPos = sub.posName.toLowerCase().contains(q);
        if (!matchCode && !matchUser && !matchTemplate && !matchPos) return false;
      }
      return true;
    }).toList();
  }
}
