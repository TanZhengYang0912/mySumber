import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/tokens.dart';
import '../../auth/state/auth_state.dart';
import '../data/worker_repository.dart';
import '../models/worker_account.dart';
import '../services/admin_tablet_layout.dart';
import '../../../theme/page_header.dart';
import '../../../theme/responsive_filter_bar.dart';

typedef _WorkerInviteDraft = ({String fullName, String email});

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
    final draft = await showDialog<_WorkerInviteDraft>(
      context: context,
      builder: (_) => const _WorkerInviteDialog(),
    );
    if (draft == null) return;
    final fullName = draft.fullName;
    final workEmail = draft.email;
    if (fullName.isEmpty) {
      _showInviteMessage("Enter the worker's full name.");
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(workEmail)) {
      _showInviteMessage('Enter a valid work email.');
      return;
    }
    try {
      await _repository.manage(
          action: 'create', fullName: fullName, email: workEmail);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Worker invited. They can log in with $workEmail as both the username and starter password, and will be asked to set a new one.')));
      await _load();
    } catch (e) {
      final error = e.toString().toLowerCase();
      final duplicate = error.contains('already exists') ||
          error.contains('already registered') ||
          error.contains('duplicate');
      _showInviteMessage(duplicate
          ? 'A worker account with this email already exists.'
          : 'Could not invite worker. Check your connection and try again.');
    }
  }

  void _showInviteMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
    final filterBar = ResponsiveFilterBar(
      mode: isPhoneLandscape
          ? ResponsiveFilterBarMode.menu
          : ResponsiveFilterBarMode.inline,
      searchController: _search,
      onSearchChanged: (_) => setState(() {}),
      activeFilterCount:
          countActiveFilters(query: _search.text, filters: const []),
      filters: const [],
    );
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          _header(action: isPhoneLandscape ? filterBar : null),
          if (!isPhoneLandscape) filterBar,
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
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
                  ...visible
                      .map((worker) => _workerCard(worker, horizontalInset)),
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
          ),
        ],
      ),
    );
  }

  Widget _header({Widget? action}) {
    return PageHeader(
      title: 'Worker Accounts',
      icon: Icons.manage_accounts_outlined,
      onLogout: () => context.read<RoleState>().logout(),
      action: action,
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

class _WorkerInviteDialog extends StatefulWidget {
  const _WorkerInviteDialog();

  @override
  State<_WorkerInviteDialog> createState() => _WorkerInviteDialogState();
}

class _WorkerInviteDialogState extends State<_WorkerInviteDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Add worker'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Full name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Work email'),
        ),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop<_WorkerInviteDraft>(
            context,
            (
              fullName: _name.text.trim(),
              email: _email.text.trim().toLowerCase(),
            ),
          ),
          child: const Text('Send invite'),
        ),
      ],
    );
  }
}
