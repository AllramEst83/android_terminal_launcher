import 'package:android_terminal_launcher/services/local_store_exception.dart';
import 'package:android_terminal_launcher/services/view_mode.dart';
import 'package:android_terminal_launcher/services/view_mode_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/in_memory_local_store.dart';

void main() {
  test('starts rich', () {
    expect(
      ViewModeController(store: InMemoryLocalStore()).current,
      ViewMode.rich,
    );
  });

  group('load', () {
    test('applies the saved mode', () async {
      final store = InMemoryLocalStore();
      await store.write(ViewModeController.storeKey, 'plain');
      final controller = ViewModeController(store: store);

      await controller.load();

      expect(controller.current, ViewMode.plain);
    });

    test('keeps the default for nothing, nonsense or a wrong type', () async {
      final store = InMemoryLocalStore();
      final controller = ViewModeController(store: store);

      await controller.load();
      expect(controller.current, ViewMode.rich);

      await store.write(ViewModeController.storeKey, 'fancy');
      await controller.load();
      expect(controller.current, ViewMode.rich);

      await store.write(ViewModeController.storeKey, 7);
      await controller.load();
      expect(controller.current, ViewMode.rich);
    });

    test('keeps the default when the store cannot be read', () async {
      final controller = ViewModeController(
        store: InMemoryLocalStore(
          failure: const LocalStoreException('unreadable'),
        ),
      );

      await controller.load();

      expect(controller.current, ViewMode.rich);
    });
  });

  group('select', () {
    test('changes the mode and saves it', () async {
      final store = InMemoryLocalStore();
      final controller = ViewModeController(store: store);

      await controller.select(ViewMode.plain);

      expect(controller.current, ViewMode.plain);
      expect(await store.read(ViewModeController.storeKey), 'plain');
    });

    test('a choice survives a restart', () async {
      final store = InMemoryLocalStore();
      await ViewModeController(store: store).select(ViewMode.plain);

      final restarted = ViewModeController(store: store);
      await restarted.load();

      expect(restarted.current, ViewMode.plain);
    });

    test('a failed save still changes the mode, then throws', () async {
      final controller = ViewModeController(
        store: InMemoryLocalStore(
          failure: const LocalStoreException('disk full'),
        ),
      );

      await expectLater(
        controller.select(ViewMode.plain),
        throwsA(isA<LocalStoreException>()),
      );

      expect(controller.current, ViewMode.plain);
    });
  });

  test('parse finds a mode by name, ignoring case', () {
    expect(ViewMode.parse('Plain'), ViewMode.plain);
    expect(ViewMode.parse('RICH'), ViewMode.rich);
    expect(ViewMode.parse('fancy'), isNull);
    expect(ViewMode.parse(''), isNull);
  });
}
