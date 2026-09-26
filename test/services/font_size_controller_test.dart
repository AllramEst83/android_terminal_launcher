import 'package:android_terminal_launcher/services/font_size_choice.dart';
import 'package:android_terminal_launcher/services/font_size_controller.dart';
import 'package:android_terminal_launcher/services/local_store_exception.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/in_memory_local_store.dart';

FontSizeController _controller(InMemoryLocalStore store) {
  final controller = FontSizeController(store: store);
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  test('starts on the normal size', () {
    expect(_controller(InMemoryLocalStore()).current, FontSizeChoice.normal);
  });

  group('load', () {
    test('applies the saved size', () async {
      final store = InMemoryLocalStore();
      await store.write(FontSizeController.storeKey, 'huge');
      final controller = _controller(store);

      await controller.load();

      expect(controller.current, FontSizeChoice.huge);
    });

    test('keeps the default when nothing is saved', () async {
      final controller = _controller(InMemoryLocalStore());

      await controller.load();

      expect(controller.current, FontSizeChoice.normal);
    });

    test('ignores a saved value that is not a known size', () async {
      final store = InMemoryLocalStore();
      final controller = _controller(store);

      await store.write(FontSizeController.storeKey, 'gigantic');
      await controller.load();
      expect(controller.current, FontSizeChoice.normal);

      await store.write(FontSizeController.storeKey, 42);
      await controller.load();
      expect(controller.current, FontSizeChoice.normal);
    });

    test('keeps the default when the store cannot be read', () async {
      final store = InMemoryLocalStore(
        failure: const LocalStoreException('unreadable'),
      );
      final controller = _controller(store);

      await controller.load();

      expect(controller.current, FontSizeChoice.normal);
    });

    test('notifies when the saved size differs from the default', () async {
      final store = InMemoryLocalStore();
      await store.write(FontSizeController.storeKey, 'large');
      final controller = _controller(store);
      var notified = 0;
      controller.addListener(() => notified++);

      await controller.load();

      expect(notified, 1);
    });
  });

  group('select', () {
    test('changes the size, notifies and saves it', () async {
      final store = InMemoryLocalStore();
      final controller = _controller(store);
      var notified = 0;
      controller.addListener(() => notified++);

      await controller.select(FontSizeChoice.large);

      expect(controller.current, FontSizeChoice.large);
      expect(notified, 1);
      expect(await store.read(FontSizeController.storeKey), 'large');
    });

    test('a choice survives a restart', () async {
      final store = InMemoryLocalStore();
      await _controller(store).select(FontSizeChoice.huge);

      final restarted = _controller(store);
      await restarted.load();

      expect(restarted.current, FontSizeChoice.huge);
    });

    test('selecting the current size does not notify', () async {
      final controller = _controller(InMemoryLocalStore());
      var notified = 0;
      controller.addListener(() => notified++);

      await controller.select(FontSizeChoice.normal);

      expect(notified, 0);
    });

    test('a failed save still changes the size, then throws', () async {
      final controller = _controller(
        InMemoryLocalStore(failure: const LocalStoreException('disk full')),
      );

      await expectLater(
        controller.select(FontSizeChoice.large),
        throwsA(isA<LocalStoreException>()),
      );

      expect(controller.current, FontSizeChoice.large);
    });
  });

  group('FontSizeChoice.parse', () {
    test('finds a size by name, ignoring case', () {
      expect(FontSizeChoice.parse('Huge'), FontSizeChoice.huge);
      expect(FontSizeChoice.parse('LARGE'), FontSizeChoice.large);
    });

    test('is null for anything else', () {
      expect(FontSizeChoice.parse('gigantic'), isNull);
      expect(FontSizeChoice.parse(''), isNull);
    });
  });
}
