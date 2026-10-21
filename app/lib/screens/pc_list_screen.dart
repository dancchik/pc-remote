import 'package:flutter/material.dart';

import '../models/pc.dart';
import '../services/agent_client.dart';
import '../services/pc_storage.dart';
import '../widgets/confirm_dialog.dart';
import 'pc_detail_screen.dart';
import 'pc_edit_screen.dart';

/// Home screen: all saved PCs with their online status.
class PcListScreen extends StatefulWidget {
  const PcListScreen({super.key});

  @override
  State<PcListScreen> createState() => _PcListScreenState();
}

class _PcListScreenState extends State<PcListScreen> {
  final _storage = PcStorage();
  List<Pc>? _pcs;

  // Latest check result per PC id: a status if online, an error message otherwise.
  final _statuses = <String, PcStatus>{};
  final _errors = <String, String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pcs = await _storage.load();
    setState(() => _pcs = pcs);
    await _refreshAll();
  }

  Future<void> _refreshAll() => Future.wait(_pcs!.map(_refresh));

  Future<void> _refresh(Pc pc) async {
    final client = AgentClient(pc);
    try {
      final status = await client.getStatus();
      if (!mounted) return;
      setState(() {
        _statuses[pc.id] = status;
        _errors.remove(pc.id);
      });
    } on AgentException catch (e) {
      if (!mounted) return;
      setState(() {
        _errors[pc.id] = e.message;
        _statuses.remove(pc.id);
      });
    } finally {
      client.close();
    }
  }

  Future<void> _add() async {
    final pc = await Navigator.push<Pc>(
      context,
      MaterialPageRoute(builder: (_) => const PcEditScreen()),
    );
    if (pc == null) return;
    setState(() => _pcs!.add(pc));
    await _storage.save(_pcs!);
    await _refresh(pc);
  }

  Future<void> _edit(Pc pc) async {
    final updated = await Navigator.push<Pc>(
      context,
      MaterialPageRoute(builder: (_) => PcEditScreen(pc: pc)),
    );
    if (updated == null) return;
    setState(() {
      final index = _pcs!.indexWhere((p) => p.id == pc.id);
      _pcs![index] = updated;
    });
    await _storage.save(_pcs!);
    await _refresh(updated);
  }

  Future<void> _delete(Pc pc) async {
    final ok = await confirm(
      context,
      title: 'Удалить ${pc.name}?',
      message: 'ПК пропадёт из списка. Агент на самом ПК останется.',
      action: 'Удалить',
    );
    if (!ok) return;
    setState(() => _pcs!.removeWhere((p) => p.id == pc.id));
    await _storage.save(_pcs!);
  }

  Future<void> _open(Pc pc) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PcDetailScreen(pc: pc)),
    );
    await _refresh(pc);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Мои ПК')),
      floatingActionButton: FloatingActionButton(
        onPressed: _pcs == null ? null : _add,
        tooltip: 'Добавить ПК',
        child: const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final pcs = _pcs;
    if (pcs == null) return const Center(child: CircularProgressIndicator());
    if (pcs.isEmpty) {
      return const Center(child: Text('Пока нет ни одного ПК.\nНажмите +, чтобы добавить.', textAlign: TextAlign.center));
    }
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        children: [for (final pc in pcs) _buildTile(pc)],
      ),
    );
  }

  Widget _buildTile(Pc pc) {
    final status = _statuses[pc.id];
    final error = _errors[pc.id];
    final (Color color, String subtitle) = switch ((status, error)) {
      (final s?, _) => (Colors.green, 'CPU ${s.cpuPercent.round()}% · RAM ${s.ramPercent.round()}%'),
      (_, final e?) => (Colors.red, e),
      _ => (Colors.grey, 'Проверка…'),
    };

    return ListTile(
      leading: Icon(Icons.circle, color: color, size: 14),
      title: Text(pc.name),
      subtitle: Text(subtitle),
      onTap: () => _open(pc),
      trailing: PopupMenuButton<String>(
        onSelected: (value) => value == 'edit' ? _edit(pc) : _delete(pc),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Изменить')),
          PopupMenuItem(value: 'delete', child: Text('Удалить')),
        ],
      ),
    );
  }
}
