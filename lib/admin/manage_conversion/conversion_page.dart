import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../admin_supabase.dart';

class ConversionPage extends StatefulWidget {
  const ConversionPage({super.key});

  @override
  State<ConversionPage> createState() => _ConversionPageState();
}

class _ConversionPageState extends State<ConversionPage> {
  final _admin = AdminSupabase.client;
  bool _isLoading = true;
  bool _isSaving = false;

  int _baseAmount = 100000;
  List<Map<String, dynamic>> _tiers = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final config = await _admin.from('app_config').select('value').eq('key', 'point_tiering_rules').maybeSingle();
      if (config != null && config['value'] != null) {
        final data = jsonDecode(config['value'].toString());
        _baseAmount = data['base_amount'] ?? 100000;
        _tiers = List<Map<String, dynamic>>.from(data['tiers'] ?? []);
      } else {
        _tiers = [
          {'min': 0, 'max': 4999999, 'multiplier': 0.0},
          {'min': 5000000, 'max': 9999999, 'multiplier': 1.0},
          {'min': 10000000, 'max': 24999999, 'multiplier': 1.1},
          {'min': 25000000, 'max': 49999999, 'multiplier': 1.2},
          {'min': 50000000, 'max': 74999999, 'multiplier': 1.3},
          {'min': 75000000, 'max': 99999999, 'multiplier': 1.4},
          {'min': 100000000, 'max': null, 'multiplier': 1.5},
        ];
      }
      _tiers.sort((a, b) => (a['min'] as num).compareTo(b['min'] as num));
    } catch (e) {
      debugPrint('Load tier error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveData() async {
    setState(() => _isSaving = true);
    try {
      _tiers.sort((a, b) => (a['min'] as num).compareTo(b['min'] as num));
      final payload = jsonEncode({'base_amount': _baseAmount, 'tiers': _tiers});
      await _admin.from('app_config').upsert({'key': 'point_tiering_rules', 'value': payload}, onConflict: 'key');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aturan Tiering berhasil disimpan!'), backgroundColor: Color(0xFF10B981)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: const Color(0xFFEF4444)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _editBaseAmount() {
    final ctrl = TextEditingController(text: _baseAmount.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kelipatan Poin (Base Amount)'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(prefixText: 'Rp ', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(ctrl.text.trim()) ?? 0;
              if (val > 0) {
                setState(() => _baseAmount = val);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Simpan'),
          )
        ],
      ),
    );
  }

  void _showTierDialog({int? index}) {
    final isEdit = index != null;
    final Map<String, dynamic> tier = isEdit ? _tiers[index] : {'min': 0, 'max': null, 'multiplier': 1.0};
    
    final minCtrl = TextEditingController(text: tier['min'].toString());
    final maxCtrl = TextEditingController(text: tier['max']?.toString() ?? '');
    final multCtrl = TextEditingController(text: tier['multiplier'].toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit Tier' : 'Tambah Tier Baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: minCtrl, decoration: const InputDecoration(labelText: 'Batas Bawah (Min) Rp')),
            const SizedBox(height: 10),
            TextField(controller: maxCtrl, decoration: const InputDecoration(labelText: 'Batas Atas (Max) Rp', hintText: 'Kosongkan jika > (Tak Terhingga)')),
            const SizedBox(height: 10),
            TextField(controller: multCtrl, decoration: const InputDecoration(labelText: 'Multiplier (Nilai Poin)')),
          ],
        ),
        actions: [
          if (isEdit) TextButton(onPressed: () { setState(() => _tiers.removeAt(index)); Navigator.pop(ctx); }, child: const Text('Hapus', style: TextStyle(color: Colors.red))),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                final newTier = {
                  'min': int.tryParse(minCtrl.text) ?? 0,
                  'max': maxCtrl.text.isEmpty ? null : int.tryParse(maxCtrl.text),
                  'multiplier': double.tryParse(multCtrl.text) ?? 0.0,
                };
                if (isEdit) _tiers[index] = newTier; else _tiers.add(newTier);
                _tiers.sort((a, b) => (a['min'] as num).compareTo(b['min'] as num));
              });
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          )
        ],
      ),
    );
  }

  String _formatRp(dynamic val) {
    if (val == null) return 'Tak Terhingga';
    return val.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Aturan Tiering Poin', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveData,
                  icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save),
                  label: const Text('Simpan ke Server'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
                )
              ],
            ),
            const SizedBox(height: 20),
            ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
              title: const Text('Kelipatan Dasar (Base Amount)'),
              subtitle: Text('Setiap Rp ${_formatRp(_baseAmount)} akan dikalikan dengan multiplier tier.'),
              trailing: ElevatedButton(onPressed: _editBaseAmount, child: const Text('Ubah')),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Daftar Tiering Belanja', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                OutlinedButton.icon(onPressed: () => _showTierDialog(), icon: const Icon(Icons.add), label: const Text('Tambah Tier'))
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(_tiers.length, (i) {
              final t = _tiers[i];
              return Card(
                elevation: 0, margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.blue[50], child: Text('${i+1}')),
                  title: Text('Rp ${_formatRp(t['min'])}  -  Rp ${_formatRp(t['max'])}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Multiplier: ${t['multiplier']} Poin'),
                  trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => _showTierDialog(index: i)),
                ),
              );
            })
          ],
        ),
      ),
    );
  }
}