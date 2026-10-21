import 'dart:async';

import 'package:flutter/material.dart';

import '../models/pc.dart';
import '../services/agent_client.dart';
import '../widgets/confirm_dialog.dart';
import 'screenshot_screen.dart';

/// One PC: live status and control buttons.
class PcDetailScreen extends StatefulWidget {
  final Pc pc;

  const PcDetailScreen({super.key, required this.pc});

  @override
  State<PcDetailScreen> createState() => _PcDetailScreenState();
}

class _PcDetailScreenState extends State<PcDetailScreen> {
  static const _refreshInterval = Duration(seconds: 5);

  late final AgentClient _client = AgentClient(widget.pc);
  Timer? _timer;
  PcStatus? _status;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(_refreshInterval, (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _client.close();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final status = await _client.getStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        _error = null;
      });
    } on AgentException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Runs [action] with buttons disabled and shows the result in a snackbar.
  Future<void> _perform(Future<void> Function() action, String successMessage) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) _showMessage(successMessage);
    } on AgentException catch (e) {
      if (mounted) _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _power(PowerCommand command) async {
    final name = widget.pc.name;
    final question = switch (command) {
      PowerCommand.lock => null,
      PowerCommand.sleep => 'Отправить $name в сон? Разбудить его с телефона не получится.',
      PowerCommand.restart => 'Перезагрузить $name? Несохранённые данные пропадут.',
      PowerCommand.shutdown => 'Выключить $name? Включить его с телефона не получится.',
    };
    if (question != null) {
      final ok = await confirm(context, title: 'Подтверждение', message: question, action: 'Да');
      if (!ok) return;
    }

    final needsConfirmFlag = command == PowerCommand.restart || command == PowerCommand.shutdown;
    await _perform(
      () => _client.sendPowerCommand(command, confirmed: needsConfirmFlag),
      'Команда отправлена',
    );
  }

  Future<void> _runProgram() async {
    final input = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _RunProgramDialog(),
    );
    if (input == null || !mounted) return;
    final (program, arguments) = input;

    final ok = await confirm(
      context,
      title: 'Подтверждение',
      message: 'Запустить на ${widget.pc.name}:\n$program $arguments',
      action: 'Запустить',
    );
    if (!ok) return;
    await _perform(() => _client.runProgram(program, arguments), 'Запущено: $program');
  }

  void _openScreenshot() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ScreenshotScreen(pc: widget.pc, client: _client)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.pc.name)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) _ErrorCard(message: _error!),
            if (_status != null) _StatusCard(status: _status!, stale: _error != null),
            if (_status == null && _error == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            const SizedBox(height: 24),
            _buildButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildButtons() {
    Widget button(IconData icon, String label, VoidCallback onPressed) => FilledButton.tonalIcon(
          onPressed: _busy ? null : onPressed,
          icon: Icon(icon),
          label: Text(label),
        );

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.6,
      children: [
        button(Icons.screenshot_monitor, 'Скриншот', _openScreenshot),
        button(Icons.play_arrow, 'Запустить', _runProgram),
        button(Icons.lock, 'Блокировка', () => _power(PowerCommand.lock)),
        button(Icons.bedtime, 'Сон', () => _power(PowerCommand.sleep)),
        button(Icons.restart_alt, 'Перезагрузка', () => _power(PowerCommand.restart)),
        button(Icons.power_settings_new, 'Выключение', () => _power(PowerCommand.shutdown)),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.errorContainer,
      child: ListTile(
        leading: Icon(Icons.cloud_off, color: colors.onErrorContainer),
        title: Text(message, style: TextStyle(color: colors.onErrorContainer)),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final PcStatus status;

  /// True if this is the last known status and the PC doesn't answer now.
  final bool stale;

  const _StatusCard({required this.status, required this.stale});

  @override
  Widget build(BuildContext context) {
    final s = status;
    return Opacity(
      opacity: stale ? 0.5 : 1,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.hostname, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              _Meter(label: 'CPU', percent: s.cpuPercent, detail: '${s.cpuPercent.round()}%'),
              const SizedBox(height: 12),
              _Meter(
                label: 'RAM',
                percent: s.ramPercent,
                detail: '${s.ramUsedGb} из ${s.ramTotalGb} ГБ',
              ),
              const SizedBox(height: 16),
              Text('Работает: ${formatUptime(s.uptimeSeconds)}'),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  final String label;
  final double percent;
  final String detail;

  const _Meter({required this.label, required this.percent, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(label), Text(detail)],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: percent / 100, minHeight: 8, borderRadius: BorderRadius.circular(4)),
      ],
    );
  }
}

class _RunProgramDialog extends StatefulWidget {
  const _RunProgramDialog();

  @override
  State<_RunProgramDialog> createState() => _RunProgramDialogState();
}

class _RunProgramDialogState extends State<_RunProgramDialog> {
  final _program = TextEditingController();
  final _arguments = TextEditingController();

  @override
  void dispose() {
    _program.dispose();
    _arguments.dispose();
    super.dispose();
  }

  void _submit() {
    final program = _program.text.trim();
    if (program.isEmpty) return;
    Navigator.pop(context, (program, _arguments.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Запустить программу'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _program,
            autofocus: true,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Программа',
              hintText: 'notepad, chrome, C:\\...\\app.exe',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _arguments,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Аргументы (необязательно)'),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(onPressed: _submit, child: const Text('Далее')),
      ],
    );
  }
}

/// Formats seconds as "3 д 4 ч", "4 ч 12 мин" or "12 мин".
String formatUptime(int seconds) {
  final days = seconds ~/ 86400;
  final hours = seconds % 86400 ~/ 3600;
  final minutes = seconds % 3600 ~/ 60;
  if (days > 0) return '$days д $hours ч';
  if (hours > 0) return '$hours ч $minutes мин';
  return '$minutes мин';
}
