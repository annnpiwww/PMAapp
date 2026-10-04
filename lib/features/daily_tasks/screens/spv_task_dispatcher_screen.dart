import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/daily_task_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/daily_task_service.dart';

class SpvTaskDispatcherScreen extends StatefulWidget {
  const SpvTaskDispatcherScreen({super.key});

  @override
  State<SpvTaskDispatcherScreen> createState() => _SpvTaskDispatcherScreenState();
}

class _SpvTaskDispatcherScreenState extends State<SpvTaskDispatcherScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<DailyTaskModel> _tasksToday = [];

  final List<String> _technicians = [
    'Ryan Lumasuge',
    'Raldy Sangkop',
    'Junifer Manua',
    'Alessandro',
  ];

  String _selectedTech = 'Ryan Lumasuge';
  final _lokasiCtrl = TextEditingController(text: 'TBM');
  final _pekerjaanCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();
  String _taskCategory = 'khusus'; // 'khusus' atau 'maintenance'
  String? _selectedTemplateId = 'tpl_maint_pos';

  final List<Map<String, String>> _templates = [
    {'id': 'tpl_maint_pos', 'nama': 'Maintenance Pos Kasir'},
    {'id': 'tpl_maint_manless', 'nama': 'Maintenance Manless Gate'},
    {'id': 'tpl_maint_barrier', 'nama': 'Maintenance Barrier Gate'},
    {'id': 'tpl_maint_server', 'nama': 'Maintenance PC Server & Kasir'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _lokasiCtrl.dispose();
    _pekerjaanCtrl.dispose();
    _catatanCtrl.dispose();
    super.dispose();
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    final tasks = await DailyTaskService.getAllTasksToday(_todayStr());
    if (mounted) {
      setState(() {
        _tasksToday = tasks;
        _isLoading = false;
      });
    }
  }

  Future<void> _submitTask() async {
    if (_isLoading) return; // Anti-double submit

    final lokasi = _lokasiCtrl.text.trim();
    final pekerjaan = _pekerjaanCtrl.text.trim();

    if (lokasi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lokasi wajib diisi')),
      );
      return;
    }

    if (pekerjaan.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Detail pekerjaan wajib diisi')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final res = await DailyTaskService.createTask(
      tanggal: _todayStr(),
      teknisiNama: _selectedTech,
      posName: lokasi,
      posTag: lokasi,
      judul: pekerjaan,
      deskripsi: _catatanCtrl.text.trim(),
      kategori: _taskCategory,
      templateId: _taskCategory == 'maintenance' ? _selectedTemplateId : null,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (res != null) {
        _pekerjaanCtrl.clear();
        _catatanCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tugas berhasil dikirim ke $_selectedTech'),
            backgroundColor: AppColors.success,
          ),
        );
        _tabController.animateTo(1);
        _loadTasks();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengirim tugas. Coba lagi.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthRepository.instance.currentUser;
    if (user?.role != UserRole.supervisor) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Akses Dibatasi'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Halaman ini khusus untuk Supervisor (SPV).\nTeknisi hanya melihat tugas di layar utama kamera.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Text(
          'Penugasan Teknisi',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: const Color(0xFF94A3B8),
          tabs: const [
            Tab(text: 'Beri Tugas'),
            Tab(text: 'Status Tim'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFormTugaskan(),
          _buildListPantau(),
        ],
      ),
    );
  }

  Widget _buildFormTugaskan() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Segment Jenis Tugas
          const Text(
            'Jenis Tugas *',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFCBD5E1)),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _taskCategory = 'khusus'),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _taskCategory == 'khusus' ? AppColors.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Tugas Khusus',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _taskCategory == 'khusus' ? Colors.white : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _taskCategory = 'maintenance'),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _taskCategory == 'maintenance' ? AppColors.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Maintenance SOP',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _taskCategory == 'maintenance' ? Colors.white : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Dropdown Teknisi
          const Text(
            'Pilih Teknisi *',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFCBD5E1)),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedTech,
                isExpanded: true,
                dropdownColor: const Color(0xFF111827),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                items: _technicians.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedTech = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Template jika Maintenance SOP
          if (_taskCategory == 'maintenance') ...[
            const Text(
              'Template SOP *',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFCBD5E1)),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedTemplateId,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF111827),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  items: _templates.map((tpl) => DropdownMenuItem(value: tpl['id'], child: Text(tpl['nama']!))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedTemplateId = val;
                        final found = _templates.firstWhere((e) => e['id'] == val);
                        _pekerjaanCtrl.text = '${found['nama']} - ${_lokasiCtrl.text.trim()}';
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Lokasi Manual Murni
          const Text(
            'Lokasi *',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFCBD5E1)),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _lokasiCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Contoh: TBM, MTC, Pos 1',
              hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF111827),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.accent)),
            ),
          ),
          const SizedBox(height: 16),

          // Detail Pekerjaan
          const Text(
            'Detail Pekerjaan *',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFCBD5E1)),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _pekerjaanCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Contoh: Pengecatan markah panah lokasi TBM',
              hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF111827),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.accent)),
            ),
          ),
          const SizedBox(height: 16),

          // Catatan Tambahan
          const Text(
            'Catatan (Opsional)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFCBD5E1)),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _catatanCtrl,
            maxLines: 2,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Instruksi atau catatan khusus jika ada',
              hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF111827),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.accent)),
            ),
          ),
          const SizedBox(height: 24),

          // Tombol Kirim Tugas (Min height 46px)
          ElevatedButton(
            onPressed: _isLoading ? null : _submitTask,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Kirim Tugas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildListPantau() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    if (_tasksToday.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.assignment_outlined, size: 40, color: Color(0xFF475569)),
            const SizedBox(height: 10),
            const Text(
              'Belum ada tugas dibuat hari ini',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _loadTasks,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Muat Ulang'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFCBD5E1),
                side: const BorderSide(color: Color(0xFF334155)),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      color: AppColors.accent,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _tasksToday.length,
        separatorBuilder: (_, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final t = _tasksToday[index];
          final isDone = t.isCompleted;

          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDone ? AppColors.success.withValues(alpha: 0.3) : const Color(0xFF334155),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      t.teknisiNama,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDone ? AppColors.success.withValues(alpha: 0.15) : const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isDone ? 'Selesai (${t.jamSelesai ?? ""})' : 'Pending',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDone ? AppColors.success : const Color(0xFFFBBF24),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  t.judul,
                  style: const TextStyle(fontSize: 12, color: Color(0xFFE2E8F0)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Lokasi: ${t.posName}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
                if (t.catatanTeknisi != null && t.catatanTeknisi!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Catatan: "${t.catatanTeknisi}"',
                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFFCBD5E1)),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
