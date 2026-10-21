import 'package:flutter/material.dart';

import '../models/pc.dart';
import '../services/agent_client.dart';

/// Form to add a new PC or edit an existing one. Pops with the saved [Pc].
class PcEditScreen extends StatefulWidget {
  final Pc? pc;

  const PcEditScreen({super.key, this.pc});

  @override
  State<PcEditScreen> createState() => _PcEditScreenState();
}

class _PcEditScreenState extends State<PcEditScreen> {
  static const _defaultPort = 8765;

  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.pc?.name);
  late final _host = TextEditingController(text: widget.pc?.host);
  late final _port = TextEditingController(text: '${widget.pc?.port ?? _defaultPort}');
  late final _token = TextEditingController(text: widget.pc?.token);
  bool _showToken = false;
  bool _testing = false;

  @override
  void dispose() {
    for (final controller in [_name, _host, _port, _token]) {
      controller.dispose();
    }
    super.dispose();
  }

  Pc _buildPc() => Pc(
        id: widget.pc?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: _name.text.trim(),
        host: _host.text.trim(),
        port: int.parse(_port.text.trim()),
        token: _token.text.trim(),
      );

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _buildPc());
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _testing = true);
    final client = AgentClient(_buildPc());
    String message;
    try {
      final status = await client.getStatus();
      message = 'Подключено: ${status.hostname}';
    } on AgentException catch (e) {
      message = e.message;
    } finally {
      client.close();
    }
    if (!mounted) return;
    setState(() => _testing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _required(String? value) => (value == null || value.trim().isEmpty) ? 'Заполните поле' : null;

  String? _validatePort(String? value) {
    final port = int.tryParse(value?.trim() ?? '');
    return (port == null || port < 1 || port > 65535) ? 'Порт от 1 до 65535' : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pc == null ? 'Новый ПК' : 'Изменить ПК'),
        actions: [IconButton(onPressed: _save, icon: const Icon(Icons.check), tooltip: 'Сохранить')],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Название', hintText: 'Домашний ПК'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _host,
              decoration: const InputDecoration(labelText: 'Адрес', hintText: '100.64.0.5'),
              keyboardType: TextInputType.url,
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _port,
              decoration: const InputDecoration(labelText: 'Порт'),
              keyboardType: TextInputType.number,
              validator: _validatePort,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _token,
              decoration: InputDecoration(
                labelText: 'Токен',
                helperText: 'AGENT_TOKEN из файла .env на ПК',
                suffixIcon: IconButton(
                  icon: Icon(_showToken ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showToken = !_showToken),
                ),
              ),
              obscureText: !_showToken,
              autocorrect: false,
              enableSuggestions: false,
              validator: _required,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _testing ? null : _testConnection,
              icon: _testing
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.wifi_find),
              label: const Text('Проверить подключение'),
            ),
          ],
        ),
      ),
    );
  }
}
