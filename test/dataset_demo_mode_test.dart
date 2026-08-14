import 'package:flutter_test/flutter_test.dart';

import 'package:mysumber/modules/dataset/data/dataset_repository.dart';
import 'package:mysumber/modules/dataset/models/models.dart';
import 'package:mysumber/modules/dataset/state/dataset_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('empty production inventory does not auto-seed demo records', () async {
    final repository = _EmptyRepository();
    final state = DatasetState(repository: repository);

    await state.loadNodes();

    expect(state.nodes, isEmpty);
    expect(repository.seedCallCount, 0);
  });
}

class _EmptyRepository extends DatasetRepository {
  int seedCallCount = 0;

  @override
  Future<List<EquipmentNode>> fetchNodes() async => const [];

  @override
  Future<void> seedDemoDataIfEmpty() async {
    seedCallCount++;
  }
}
