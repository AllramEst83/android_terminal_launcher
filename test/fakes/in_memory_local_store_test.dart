import 'package:flutter_test/flutter_test.dart';

import '../services/local_store_contract.dart';
import 'in_memory_local_store.dart';

void main() {
  localStoreContract(InMemoryLocalStore.new);

  test('failure is thrown by every call until cleared', () async {
    final store = InMemoryLocalStore(failure: StateError('disk full'));

    await expectLater(store.read('k'), throwsStateError);
    await expectLater(store.write('k', 1), throwsStateError);
    await expectLater(store.delete('k'), throwsStateError);
    expect(store.writes, 0);

    store.failure = null;
    await store.write('k', 1);
    expect(store.writes, 1);
  });
}
