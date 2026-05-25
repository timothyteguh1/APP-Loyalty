import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../admin_supabase.dart';

class UserDetailsPage extends StatefulWidget {
  const UserDetailsPage({super.key});

  @override
  State<UserDetailsPage> createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends State<UserDetailsPage> {
  final _admin = AdminSupabase.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final data = await _admin
          .from('profiles')
          .select()
          .eq('approval_status', 'APPROVED')
          .order('points', ascending: false);
      
      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(data);
          _filteredUsers = _users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _filterUsers(String query) {
    final q = query.toLowerCase();
    setState(() {
      _filteredUsers = _users.where((user) {
        final name = (user['full_name'] ?? '').toString().toLowerCase();
        final email = (user['email'] ?? '').toString().toLowerCase();
        final accId = (user['accurate_customer_id'] ?? '').toString().toLowerCase();
        return name.contains(q) || email.contains(q) || accId.contains(q);
      }).toList();
    });
  }

  // --- POPUP HISTORI POIN ---
  void _showHistoryDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => _UserHistoryDialog(
        userId: user['id'],
        userName: user['full_name'] ?? 'User',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Rincian Poin User', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E), fontSize: 22)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pencarian
                TextField(
                  controller: _searchCtrl,
                  onChanged: _filterUsers,
                  decoration: InputDecoration(
                    hintText: 'Cari Nama, Email, atau ID Accurate...',
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Daftar User
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFB71C1C)))
                      : _filteredUsers.isEmpty
                          ? const Center(child: Text('Tidak ada data user ditemukan.', style: TextStyle(color: Colors.grey)))
                          : isDesktop
                              ? _buildDesktopTable()
                              : _buildMobileList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF0F0F0))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8F9FC)),
            showCheckboxColumn: false,
            columns: const [
              DataColumn(label: Text('Nama Toko', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Email / Kontak', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('ID Accurate', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Total Poin', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _filteredUsers.map((user) {
              return DataRow(
                onSelectChanged: (_) => _showHistoryDialog(user),
                cells: [
                  DataCell(Text(user['full_name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(Text('${user['email'] ?? '-'}\n${user['phone'] ?? '-'}', style: const TextStyle(fontSize: 12, color: Colors.grey))),
                  DataCell(Text(user['accurate_customer_id'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w500))),
                  DataCell(Text('${user['points'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFB71C1C), fontSize: 16))),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileList() {
    return ListView.builder(
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFF0F0F0))),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            onTap: () => _showHistoryDialog(user),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFB71C1C).withOpacity(0.1),
              child: const Icon(Icons.storefront_rounded, color: Color(0xFFB71C1C)),
            ),
            title: Text(user['full_name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('ID: ${user['accurate_customer_id'] ?? '-'}', style: const TextStyle(fontSize: 12)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Poin', style: TextStyle(fontSize: 10, color: Colors.grey)),
                Text('${user['points'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFB71C1C), fontSize: 16)),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =====================================================================
// WIDGET POPUP HISTORI POIN
// =====================================================================
class _UserHistoryDialog extends StatefulWidget {
  final String userId;
  final String userName;
  const _UserHistoryDialog({required this.userId, required this.userName});

  @override
  State<_UserHistoryDialog> createState() => _UserHistoryDialogState();
}

class _UserHistoryDialogState extends State<_UserHistoryDialog> {
  final _admin = AdminSupabase.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _histories = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final data = await _admin
          .from('point_history')
          .select()
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _histories = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 600,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text('Histori: ${widget.userName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const Divider(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _histories.isEmpty
                      ? const Center(child: Text('Belum ada histori poin.', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: _histories.length,
                          itemBuilder: (context, index) {
                            final h = _histories[index];
                            final amount = (h['amount'] as num?)?.toInt() ?? 0;
                            final isPos = amount > 0;
                            final color = isPos ? Colors.green : Colors.red;
                            
                            String dateStr = '';
                            if (h['created_at'] != null) {
                              dateStr = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(h['created_at']).toLocal());
                            }

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                                child: Icon(isPos ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: color, size: 16),
                              ),
                              title: Text(h['description'] ?? '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              subtitle: Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              trailing: Text('${isPos ? "+" : ""}$amount', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}