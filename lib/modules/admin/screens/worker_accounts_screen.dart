import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/tokens.dart';
import '../../auth/state/auth_state.dart';
import '../data/worker_repository.dart';
import '../models/worker_account.dart';
import '../services/admin_tablet_layout.dart';
import '../widgets/admin_page_header.dart';

class WorkerAccountsScreen extends StatefulWidget {
  const WorkerAccountsScreen({super.key, this.repository});

  final WorkerRepository? repository;

  @override
  State<WorkerAccountsScreen> createState() => _WorkerAccountsScreenState();
}

class _WorkerAccountsScreenState extends State<WorkerAccountsScreen> {
  late final WorkerRepository _repository =
      widget.repository ?? WorkerRepository();
  final _search = TextEditingController();
  List<WorkerAccount> _workers = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final workers = await _repository.listWorkers();
      if (mounted) {
        setState(() {
          _workers = workers;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load worker accounts';
          _loading = false;
        });
      }
    }
  }

  Future<void> _addWorker() async {
    final name = TextEditingController();
    final email = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Add worker'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Full name')),
          const SizedBox(height: 12),
          TextField(
              controller: email,
              decoration: const InputDecoration(labelText: 'Work email')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Send invite')),
        ],
      ),
    );
    if (submit != true ||
        name.text.trim().isEmpty ||
        !email.text.contains('@')) {
      return;
    }
    try {
      await _repository.manage(
          action: 'create',
          fullName: name.text.trim(),
          email: email.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Worker invited successfully. A password setup email has been sent.')));
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not invite worker')));
      }
    }
  }

  Future<void> _toggle(WorkerAccount worker) async {
    final action = worker.isActive ? 'deactivate' : 'activate';
    try {
      await _repository.manage(action: action, workerId: worker.id);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not update worker status')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final visible = _workers
        .where((worker) =>
            worker.fullName.toLowerCase().contains(query) ||
            worker.email.toLowerCase().contains(query))
        .toList();
    final active = _workers.where((worker) => worker.isActive).length;
    final isPhoneLandscape = adminLayoutModeFor(MediaQuery.sizeOf(context)) ==
        AdminLayoutMode.phoneLandscape;
    final horizontalInset =
        isPhoneLandscape ? adminLandscapeHorizontalInset : 20.0;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _header(),
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalInset,
                18,
                horizontalInset,
                0,
              ),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Search workers',
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalInset,
                18,
                horizontalInset,
                0,
              ),
              child: Text(
                '${_workers.length} workers · $active active',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_error != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalInset,
                  20,
                  horizontalInset,
                  0,
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.critical),
                ),
              ),
            ...visible.map((worker) => _workerCard(worker, horizontalInset)),
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalInset,
                16,
                horizontalInset,
                24,
              ),
              child: FilledButton.icon(
                onPressed: _addWorker,
                icon: const Icon(Icons.add),
                label: const Text('Add worker'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return AdminPageHeader(
      title: 'Worker Accounts',
      icon: Icons.manage_accounts_outlined,
      onLogout: () => context.read<RoleState>().logout(),
    );
  }

  Widget _workerCard(WorkerAccount worker, double horizontalInset) {
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalInset, 10, horizontalInset, 0),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            child: Text(
              worker.fullName.isEmpty ? '?' : worker.fullName[0].toUpperCase(),
            ),
          ),
          title: Text(worker.fullName),
          subtitle: Text(worker.email),
          trailing: PopupMenuButton<String>(
            onSelected: (_) => _toggle(worker),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'toggle',
                child: Text(
                  worker.isActive ? 'Deactivate account' : 'Activate account',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
