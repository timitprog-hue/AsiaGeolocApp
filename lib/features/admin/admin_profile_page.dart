import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../core/api_client.dart';
import '../../core/auth_storage.dart';
import '../auth/login_page.dart';

class AdminProfilePage extends StatefulWidget {
  const AdminProfilePage({super.key});

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _me;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final storage = AuthStorage();
      final api = ApiClient(storage);

      final res = await api.dio.get('/me');
      if (res.data is! Map) throw Exception('Response /me bukan Map');

      _me = (res.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      _error = e.response?.data?.toString() ?? e.message ?? 'Gagal memuat profile';
    } catch (e) {
      _error = e.toString();
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    final storage = AuthStorage();
    final api = ApiClient(storage);

    try {
      await api.dio.post('/logout');
    } catch (_) {}

    await storage.clearToken();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : _buildContent(cs),
      ),
    );
  }

  Widget _buildContent(ColorScheme cs) {
    final name = (_me?['name'] ?? '-').toString();
    final email = (_me?['email'] ?? '-').toString();
    final role = (_me?['role'] ?? '-').toString();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      children: [
        // Header card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(Icons.account_circle_rounded, color: cs.primary, size: 34),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.75),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      _RoleChip(role: role),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Info section
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Account', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                _InfoRow(label: 'Name', value: name),
                _InfoRow(label: 'Email', value: email),
                _InfoRow(label: 'Role', value: role),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Actions (✅ tinggal 1 logout, no double)
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.refresh_rounded, color: cs.primary),
                title: const Text('Refresh data', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('Ambil ulang data akun dari server'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _loading ? null : _load,
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.logout_rounded, color: cs.error),
                title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('Keluar dari akun admin'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _logout,
              ),
            ],
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

    final text = role.trim().isEmpty ? '-' : role.toUpperCase();
    final bg = cs.primary.withOpacity(0.12);
    final fg = cs.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final sub = Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text(label, style: TextStyle(color: sub, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, color: cs.error, size: 44),
                const SizedBox(height: 10),
                const Text('Gagal memuat profile', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
