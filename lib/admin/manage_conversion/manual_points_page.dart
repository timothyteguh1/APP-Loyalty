import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../admin_supabase.dart';

class ManualPointsPage extends StatefulWidget {
  const ManualPointsPage({super.key});

  @override
  State<ManualPointsPage> createState() => _ManualPointsPageState();
}

class _ManualPointsPageState extends State<ManualPointsPage> {
  final _supabase = Supabase.instance.client;
  final _admin = AdminSupabase.client;
  List<Map<String, dynamic>> _users = [];
  Map<String, dynamic>? _selectedUser;
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _isAdd = true;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final data = await _admin.from('profiles').select().order('full_name');
      if (mounted) setState(() { _users = List<Map<String, dynamic>>.from(data); _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitPoints() async {
    if (_selectedUser == null) {
      _showError('Pilih user terlebih dahulu');
      return;
    }
    if (_amountCtrl.text.trim().isEmpty || int.tryParse(_amountCtrl.text.trim()) == null) {
      _showError('Masukkan jumlah poin yang valid');
      return;
    }
    if (_reasonCtrl.text.trim().isEmpty) {
      _showError('Alasan wajib diisi');
      return;
    }

    final int amount = int.parse(_amountCtrl.text.trim());
    final int finalAmount = _isAdd ? amount : -amount;
    final String userName = _selectedUser!['full_name'] ?? 'User';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(color: (_isAdd ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(_isAdd ? Icons.add_circle_rounded : Icons.remove_circle_rounded, color: _isAdd ? const Color(0xFF10B981) : const Color(0xFFEF4444), size: 20)),
          const SizedBox(width: 12),
          const Text('Konfirmasi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_isAdd ? "Tambah" : "Kurangi"} $amount poin untuk:', style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF8F8FB), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.person_rounded, size: 18, color: Color(0xFF6B7280)),
              const SizedBox(width: 8),
              Text(userName, style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 8),
          Text('Alasan: ${_reasonCtrl.text.trim()}', style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isAdd ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
            child: const Text('Konfirmasi', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      // Update points
      final currentPoints = (_selectedUser!['points'] as num?)?.toInt() ?? 0;
      final newPoints = currentPoints + finalAmount;

      await _admin.from('profiles').update({
        'points': newPoints < 0 ? 0 : newPoints,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _selectedUser!['id']);

      // Insert history
      await _admin.from('point_history').insert({
        'user_id': _selectedUser!['id'],
        'amount': finalAmount,
        'description': '${_isAdd ? "Tambah" : "Kurang"} manual: ${_reasonCtrl.text.trim()}',
        'reference_type': 'MANUAL',
        'reference_id': 'MANUAL-${DateTime.now().millisecondsSinceEpoch}',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_isAdd ? "+" : "-"}$amount poin untuk $userName'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        // Reset form
        _amountCtrl.clear();
        _reasonCtrl.clear();
        setState(() => _selectedUser = null);
        _fetchUsers();
      }
    } catch (e) {
      if (mounted) _showError('Gagal: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: const Color(0xFFEF4444)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FB),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A2E))),
        title: const Text('Manual Poin', style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Info card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFD97706)),
                    SizedBox(width: 10),
                    Expanded(child: Text('Tambah atau kurangi poin user secara manual. Akan tercatat di riwayat sebagai MANUAL.', style: TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.4))),
                  ]),
                ),
                const SizedBox(height: 24),

                // Select user
                const Text('Pilih User *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _showUserPicker(),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _selectedUser != null ? const Color(0xFFF59E0B) : const Color(0xFFF0F0F0)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: _selectedUser != null ? const Color(0xFFFEF3C7) : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(child: Text(
                          _selectedUser != null ? (_selectedUser!['full_name'] ?? '?')[0].toUpperCase() : '?',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _selectedUser != null ? const Color(0xFFD97706) : const Color(0xFF9CA3AF)),
                        )),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          _selectedUser?['full_name'] ?? 'Tap untuk pilih user',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _selectedUser != null ? const Color(0xFF1A1A2E) : const Color(0xFF9CA3AF)),
                        ),
                        if (_selectedUser != null)
                          Text('Poin saat ini: ${_selectedUser!['points'] ?? 0}', style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                      ])),
                      const Icon(Icons.chevron_right_rounded, color: Color(0xFFD1D5DB)),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),

                // Add or subtract toggle
                const Text('Tipe *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: () => setState(() => _isAdd = true),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _isAdd ? const Color(0xFF10B981).withOpacity(0.08) : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _isAdd ? const Color(0xFF10B981) : Colors.grey[200]!, width: _isAdd ? 1.5 : 1),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_circle_rounded, size: 18, color: _isAdd ? const Color(0xFF10B981) : const Color(0xFF9CA3AF)),
                        const SizedBox(width: 8),
                        Text('Tambah', style: TextStyle(fontWeight: _isAdd ? FontWeight.w600 : FontWeight.w500, color: _isAdd ? const Color(0xFF10B981) : const Color(0xFF6B7280))),
                      ]),
                    ),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: GestureDetector(
                    onTap: () => setState(() => _isAdd = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: !_isAdd ? const Color(0xFFEF4444).withOpacity(0.08) : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: !_isAdd ? const Color(0xFFEF4444) : Colors.grey[200]!, width: !_isAdd ? 1.5 : 1),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.remove_circle_rounded, size: 18, color: !_isAdd ? const Color(0xFFEF4444) : const Color(0xFF9CA3AF)),
                        const SizedBox(width: 8),
                        Text('Kurangi', style: TextStyle(fontWeight: !_isAdd ? FontWeight.w600 : FontWeight.w500, color: !_isAdd ? const Color(0xFFEF4444) : const Color(0xFF6B7280))),
                      ]),
                    ),
                  )),
                ]),
                const SizedBox(height: 20),

                // Amount
                const Text('Jumlah Poin *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: _amountCtrl, keyboardType: TextInputType.number, enableInteractiveSelection: true,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: '0', hintStyle: TextStyle(color: Colors.grey[300], fontSize: 24, fontWeight: FontWeight.w700),
                    prefixIcon: Padding(padding: const EdgeInsets.only(left: 16, right: 8),
                      child: Icon(_isAdd ? Icons.add_rounded : Icons.remove_rounded, color: _isAdd ? const Color(0xFF10B981) : const Color(0xFFEF4444), size: 24)),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    filled: true, fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _isAdd ? const Color(0xFF10B981) : const Color(0xFFEF4444), width: 1.5)),
                  ),
                ),
                const SizedBox(height: 20),

                // Reason
                const Text('Alasan *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: _reasonCtrl, maxLines: 3, enableInteractiveSelection: true, style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Contoh: Kompensasi error sistem, bonus event, dll',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    filled: true, fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5)),
                  ),
                ),
                const SizedBox(height: 32),

                // Submit
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _submitPoints,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isAdd ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      foregroundColor: Colors.white, elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isSaving
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(_isAdd ? Icons.add_circle_rounded : Icons.remove_circle_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text('${_isAdd ? "Tambah" : "Kurangi"} Poin', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          ]),
                  ),
                ),
              ]),
            ),
    );
  }

  void _showUserPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String search = '';
        return StatefulBuilder(builder: (ctx, setModalState) {
          final filtered = _users.where((u) {
            final name = (u['full_name'] ?? '').toString().toLowerCase();
            return name.contains(search.toLowerCase());
          }).toList();

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.7,
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(children: [
              Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: TextField(
                  onChanged: (v) => setModalState(() => search = v),
                  enableInteractiveSelection: true,
                  decoration: InputDecoration(
                    hintText: 'Cari user...', hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400], size: 20),
                    filled: true, fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final u = filtered[i];
                    final name = u['full_name'] ?? 'Tanpa Nama';
                    final pts = (u['points'] as num?)?.toInt() ?? 0;
                    return ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)),
                        child: Center(child: Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)))),
                      ),
                      title: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: Text('$pts poin', style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                      trailing: Text(u['approval_status'] ?? '-', style: TextStyle(fontSize: 11, color: u['approval_status'] == 'APPROVED' ? const Color(0xFF10B981) : const Color(0xFF9CA3AF))),
                      onTap: () {
                        setState(() => _selectedUser = u);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ]),
          );
        });
      },
    );
  }
}