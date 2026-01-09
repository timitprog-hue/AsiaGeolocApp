import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../core/api_client.dart';
import '../../core/auth_storage.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  bool _loading = true;
  String? _error;

  final _searchCtrl = TextEditingController();
  String _role = 'sales'; // default sesuai backend kamu (sales)
  List<Map<String, dynamic>> _users = [];

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  bool _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is int) return v == 1;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return false;
  }

  Future<ApiClient> _api() async {
    final storage = AuthStorage();
    return ApiClient(storage);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = await _api();
      final qp = <String, dynamic>{
        'role': _role,
      };

      final q = _searchCtrl.text.trim();
      if (q.isNotEmpty) qp['q'] = q;

      final res = await api.dio.get('/users', queryParameters: qp);
      final data = (res.data['data'] as List<dynamic>?) ?? [];
      final list = data.map((e) => (e as Map).cast<String, dynamic>()).toList();

      setState(() {
        _users = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal memuat users.\n$e';
        _loading = false;
      });
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> u) async {
    final id = _asInt(u['id']);
    if (id <= 0) return;

    // optimistic UI
    final before = _asBool(u['is_active']);
    setState(() {
      u['is_active'] = !before;
    });

    try {
      final api = await _api();
      await api.dio.patch('/users/$id/toggle-active');
    } catch (e) {
      // rollback
      setState(() {
        u['is_active'] = before;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal update status.\n$e')),
      );
    }
  }

  Future<void> _resetPassword(Map<String, dynamic> u) async {
    final id = _asInt(u['id']);
    if (id <= 0) return;

    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Reset Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Reset password untuk:\n${u['name']} (${u['email']})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password baru',
                  hintText: 'Min 6 karakter',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Simpan')),
          ],
        );
      },
    );

    if (ok != true) return;

    final pass = ctrl.text.trim();
    if (pass.length < 6) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password minimal 6 karakter')),
      );
      return;
    }

    try {
      final api = await _api();
      await api.dio.patch('/users/$id/reset-password', data: {'password': pass});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password berhasil direset')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal reset password.\n$e')),
      );
    }
  }

  Future<void> _createUser() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String role = 'sales';

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Tambah User'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Nama'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: role,
                      items: const [
                        DropdownMenuItem(value: 'sales', child: Text('sales')),
                        DropdownMenuItem(value: 'admin', child: Text('admin')),
                      ],
                      onChanged: (v) => setLocal(() => role = v ?? 'sales'),
                      decoration: const InputDecoration(labelText: 'Role'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password (opsional)',
                        hintText: 'Kalau kosong: password123',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Buat')),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;

    final name = nameCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final pass = passCtrl.text.trim();

    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama & email wajib diisi')),
      );
      return;
    }

    try {
      final api = await _api();
      await api.dio.post('/users', data: {
        'name': name,
        'email': email,
        'role': role,
        if (pass.isNotEmpty) 'password': pass,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User berhasil dibuat')),
      );

      // reload list (kalau role nya sama, langsung keliatan)
      await _load();
    } on DioException catch (e) {
      final msg = (e.response?.data is Map)
          ? (e.response?.data['message']?.toString() ?? e.response?.data.toString())
          : e.toString();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat user.\n$msg')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat user.\n$e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;

      // ✅ TANPA Scaffold + TANPA AppBar (biar tidak double dengan AdminShell)
      return Stack(
        children: [
          // ===== CONTENT (ISI KAMU TETAP) =====
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Filter', style: TextStyle(fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _searchCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'Search (nama / email)',
                                      prefixIcon: const Icon(Icons.search_rounded),
                                      suffixIcon: IconButton(
                                        onPressed: () {
                                          _searchCtrl.clear();
                                          _load();
                                        },
                                        icon: const Icon(Icons.close_rounded),
                                      ),
                                    ),
                                    onSubmitted: (_) => _load(),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          value: _role,
                                          items: const [
                                            DropdownMenuItem(value: 'sales', child: Text('sales')),
                                            DropdownMenuItem(value: 'admin', child: Text('admin')),
                                          ],
                                          onChanged: (v) {
                                            setState(() => _role = v ?? 'sales');
                                            _load();
                                          },
                                          decoration: const InputDecoration(labelText: 'Role'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      FilledButton.icon(
                                        onPressed: _load,
                                        icon: const Icon(Icons.search_rounded),
                                        label: const Text('Terapkan'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text('Hasil: ${_users.length}', style: TextStyle(color: cs.onSurface.withOpacity(0.7))),
                          const SizedBox(height: 8),

                          if (_users.isEmpty)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: const [
                                    Icon(Icons.info_outline_rounded),
                                    SizedBox(width: 10),
                                    Expanded(child: Text('Tidak ada user pada filter ini.')),
                                  ],
                                ),
                              ),
                            )
                          else
                            ..._users.map((u) {
                              final active = _asBool(u['is_active']);
                              final role = (u['role'] ?? '').toString();
                              final name = (u['name'] ?? 'User').toString();
                              final email = (u['email'] ?? '').toString();

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: cs.primary.withOpacity(0.10),
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              child: Icon(Icons.person_rounded, color: cs.primary),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          name,
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: const TextStyle(fontWeight: FontWeight.w900),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      _RoleChip(role: role),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    email,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(color: cs.onSurface.withOpacity(0.7)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                decoration: BoxDecoration(
                                                  color: active
                                                      ? Colors.green.withOpacity(0.08)
                                                      : Colors.red.withOpacity(0.08),
                                                  borderRadius: BorderRadius.circular(14),
                                                  border: Border.all(
                                                    color: active
                                                        ? Colors.green.withOpacity(0.25)
                                                        : Colors.red.withOpacity(0.25),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      active ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                                      color: active ? Colors.green : Colors.red,
                                                      size: 18,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        active ? 'Active' : 'Inactive',
                                                        style: const TextStyle(fontWeight: FontWeight.w800),
                                                      ),
                                                    ),
                                                    Switch(
                                                      value: active,
                                                      onChanged: (_) => _toggleActive(u),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: () => _resetPassword(u),
                                                icon: const Icon(Icons.lock_reset_rounded),
                                                label: const Text('Reset Password'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),

          // ✅ FAB tetap ada walau tanpa Scaffold
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: _createUser,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Tambah'),
            ),
          ),
        ],
      );
    }
}

class _RoleChip extends StatelessWidget {
  final String role;
  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isAdmin = role == 'admin';
    final bg = isAdmin ? cs.secondary.withOpacity(0.12) : cs.primary.withOpacity(0.12);
    final fg = isAdmin ? cs.secondary : cs.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        role,
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: fg),
      ),
    );
  }
}
