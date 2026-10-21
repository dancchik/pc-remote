import 'package:flutter_test/flutter_test.dart';
import 'package:pc_remote/screens/pc_detail_screen.dart';

void main() {
  test('formatUptime picks the right units', () {
    expect(formatUptime(59), '0 мин');
    expect(formatUptime(12 * 60), '12 мин');
    expect(formatUptime(4 * 3600 + 12 * 60), '4 ч 12 мин');
    expect(formatUptime(3 * 86400 + 4 * 3600 + 59), '3 д 4 ч');
  });
}
