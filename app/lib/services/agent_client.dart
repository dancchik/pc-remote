import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/pc.dart';

/// Error with a message that can be shown to the user as is.
class AgentException implements Exception {
  final String message;
  const AgentException(this.message);

  @override
  String toString() => message;
}

/// Response of GET /status.
class PcStatus {
  final String hostname;
  final double cpuPercent;
  final double ramPercent;
  final double ramUsedGb;
  final double ramTotalGb;
  final int uptimeSeconds;

  const PcStatus({
    required this.hostname,
    required this.cpuPercent,
    required this.ramPercent,
    required this.ramUsedGb,
    required this.ramTotalGb,
    required this.uptimeSeconds,
  });

  factory PcStatus.fromJson(Map<String, dynamic> json) => PcStatus(
        hostname: json['hostname'] as String,
        cpuPercent: (json['cpu_percent'] as num).toDouble(),
        ramPercent: (json['ram_percent'] as num).toDouble(),
        ramUsedGb: (json['ram_used_gb'] as num).toDouble(),
        ramTotalGb: (json['ram_total_gb'] as num).toDouble(),
        uptimeSeconds: json['uptime_seconds'] as int,
      );
}

/// Power commands the agent understands: `POST /command/<name>`.
enum PowerCommand { lock, sleep, restart, shutdown }

/// Talks to the agent on one PC over HTTP.
class AgentClient {
  static const _timeout = Duration(seconds: 5);
  static const _screenshotTimeout = Duration(seconds: 20);

  final Pc pc;
  final http.Client _http;

  AgentClient(this.pc, {http.Client? httpClient}) : _http = httpClient ?? http.Client();

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${pc.token}',
        'Content-Type': 'application/json',
      };

  Future<PcStatus> getStatus() async {
    final response = await _send(() => _http.get(pc.uri('/status'), headers: _headers));
    return PcStatus.fromJson(_decode(response));
  }

  Future<Uint8List> getScreenshot() async {
    final response = await _send(
      () => _http.get(pc.uri('/screenshot'), headers: _headers),
      timeout: _screenshotTimeout,
    );
    return response.bodyBytes;
  }

  /// [confirmed] must be true for restart and shutdown, otherwise the agent refuses.
  Future<void> sendPowerCommand(PowerCommand command, {bool confirmed = false}) async {
    await _post('/command/${command.name}', {'confirm': confirmed});
  }

  Future<void> runProgram(String program, String arguments) async {
    await _post('/command/run', {'program': program, 'arguments': arguments, 'confirm': true});
  }

  void close() => _http.close();

  Future<http.Response> _post(String path, Map<String, dynamic> body) {
    return _send(() => _http.post(pc.uri(path), headers: _headers, body: jsonEncode(body)));
  }

  /// Runs the request and turns network and HTTP errors into [AgentException].
  Future<http.Response> _send(
    Future<http.Response> Function() request, {
    Duration timeout = _timeout,
  }) async {
    final http.Response response;
    try {
      response = await request().timeout(timeout);
    } on TimeoutException {
      throw const AgentException('ПК не отвечает');
    } on Exception {
      throw const AgentException('Нет связи с ПК');
    }

    if (response.statusCode == 200) return response;
    if (response.statusCode == 401) throw const AgentException('Неверный токен');

    String? error;
    try {
      error = _decode(response)['error'] as String?;
    } on FormatException {
      // Not JSON; fall back to the status code below.
    }
    throw AgentException('Ошибка агента: ${error ?? 'HTTP ${response.statusCode}'}');
  }

  Map<String, dynamic> _decode(http.Response response) {
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }
}
