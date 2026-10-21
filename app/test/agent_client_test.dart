import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pc_remote/models/pc.dart';
import 'package:pc_remote/services/agent_client.dart';

const _pc = Pc(id: '1', name: 'Test', host: '127.0.0.1', port: 8765, token: 'secret-token');

AgentClient _clientReturning(int code, Object body, {void Function(http.Request)? onRequest}) {
  return AgentClient(
    _pc,
    httpClient: MockClient((request) async {
      onRequest?.call(request);
      return http.Response(jsonEncode(body), code);
    }),
  );
}

void main() {
  test('getStatus sends the token and parses the response', () async {
    late http.Request sent;
    final client = _clientReturning(200, {
      'hostname': 'pc',
      'cpu_percent': 12.5,
      'ram_percent': 50,
      'ram_used_gb': 8.0,
      'ram_total_gb': 16.0,
      'uptime_seconds': 3600,
    }, onRequest: (r) => sent = r);

    final status = await client.getStatus();

    expect(sent.url.toString(), 'http://127.0.0.1:8765/status');
    expect(sent.headers['Authorization'], 'Bearer secret-token');
    expect(status.hostname, 'pc');
    expect(status.cpuPercent, 12.5);
    expect(status.ramPercent, 50.0);
  });

  test('restart sends confirm flag', () async {
    late http.Request sent;
    final client = _clientReturning(200, {'ok': true}, onRequest: (r) => sent = r);

    await client.sendPowerCommand(PowerCommand.restart, confirmed: true);

    expect(sent.url.path, '/command/restart');
    expect(jsonDecode(sent.body), {'confirm': true});
  });

  test('401 becomes a wrong token error', () async {
    final client = _clientReturning(401, {'error': 'unauthorized'});
    expect(client.getStatus(), throwsA(isA<AgentException>().having((e) => e.message, 'message', 'Неверный токен')));
  });

  test('agent error message is shown', () async {
    final client = _clientReturning(400, {'error': 'failed to start: not found'});
    expect(
      client.runProgram('nope', ''),
      throwsA(isA<AgentException>().having((e) => e.message, 'message', contains('failed to start'))),
    );
  });

  test('network failure becomes a no connection error', () async {
    final client = AgentClient(_pc, httpClient: MockClient((_) => throw http.ClientException('refused')));
    expect(client.getStatus(), throwsA(isA<AgentException>().having((e) => e.message, 'message', 'Нет связи с ПК')));
  });
}
