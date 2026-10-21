import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/pc.dart';

/// Saves the PC list (including tokens) in Android's encrypted storage.
class PcStorage {
  static const _key = 'pcs';
  final _storage = const FlutterSecureStorage();

  Future<List<Pc>> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((item) => Pc.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> save(List<Pc> pcs) async {
    final raw = jsonEncode(pcs.map((pc) => pc.toJson()).toList());
    await _storage.write(key: _key, value: raw);
  }
}
