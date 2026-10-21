import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/pc.dart';
import '../services/agent_client.dart';

/// Shows a screenshot of the PC; pinch to zoom.
class ScreenshotScreen extends StatefulWidget {
  final Pc pc;
  final AgentClient client;

  const ScreenshotScreen({super.key, required this.pc, required this.client});

  @override
  State<ScreenshotScreen> createState() => _ScreenshotScreenState();
}

class _ScreenshotScreenState extends State<ScreenshotScreen> {
  Uint8List? _image;
  String? _error;
  bool _loading = false;

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
      final image = await widget.client.getScreenshot();
      if (!mounted) return;
      setState(() => _image = image);
    } on AgentException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Экран: ${widget.pc.name}'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) return Center(child: Text(_error!));
    final image = _image;
    if (image == null) return const Center(child: CircularProgressIndicator());
    return Stack(
      children: [
        InteractiveViewer(
          maxScale: 6,
          child: Center(child: Image.memory(image, gaplessPlayback: true)),
        ),
        if (_loading) const LinearProgressIndicator(),
      ],
    );
  }
}
