/// A PC that runs the agent, as saved on the phone.
class Pc {
  final String id;
  final String name;
  final String host;
  final int port;
  final String token;

  const Pc({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.token,
  });

  /// Builds the agent URL for [path], e.g. http://100.64.0.5:8765/status.
  Uri uri(String path) => Uri(scheme: 'http', host: host, port: port, path: path);

  factory Pc.fromJson(Map<String, dynamic> json) => Pc(
        id: json['id'] as String,
        name: json['name'] as String,
        host: json['host'] as String,
        port: json['port'] as int,
        token: json['token'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'token': token,
      };
}
