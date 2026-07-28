import 'package:flutter_test/flutter_test.dart';
import 'package:mysumber/modules/admin/services/admin_tablet_layout.dart';

void main() {
  test('uses the tablet layout at the shared 840dp breakpoint', () {
    expect(usesAdminTabletLayout(839.99), isFalse);
    expect(usesAdminTabletLayout(840), isTrue);
  });
}
