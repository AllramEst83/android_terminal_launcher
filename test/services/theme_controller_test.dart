import 'package:android_terminal_launcher/services/local_store_exception.dart';
import 'package:android_terminal_launcher/services/theme_choice.dart';
import 'package:android_terminal_launcher/services/theme_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/in_memory_local_store.dart';

ThemeController _controller(InMemoryLocalStore store) {
  final controller = ThemeController(store: store);
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  test('starts on the dark theme', () {
    expect(_controller(InMemoryLocalStore()).current, ThemeChoice.dark);
  });

  group('load', () {
    test('applies the saved theme', () async {
      final store = InMemoryLocalStore();
      await store.write(ThemeController.storeKey, 'coffee');
      final controller = _controller(store);

      await controller.load();

      expect(controller.current, ThemeChoice.coffee);
    });

    test('keeps the default when nothing is saved', () async {
      final controller = _controller(InMemoryLocalStore());

      await controller.load();

      expect(controller.current, ThemeChoice.dark);
    });

    test('ignores a saved value that is not a known theme', () async {
      final store = InMemoryLocalStore();
      final controller = _controller(store);

      await store.write(ThemeController.storeKey, 'neon');
      await controller.load();
      expect(controller.current, ThemeChoice.dark);

      await store.write(ThemeController.storeKey, 42);
      await controller.load();
      expect(controller.current, ThemeChoice.dark);
    });

    test('keeps the default when the store cannot be read', () async {
      final store = InMemoryLocalStore(
        failure: const LocalStoreException('unreadable'),
      );
      final controller = _controller(store);

      await controller.load();

      expect(controller.current, ThemeChoice.dark);
    });

    test('notifies when the saved theme differs from the default', () async {
      final store = InMemoryLocalStore();
      await store.write(ThemeController.storeKey, 'light');
      final controller = _controller(store);
      var notified = 0;
      controller.addListener(() => notified++);

      await controller.load();

      expect(notified, 1);
    });
  });

  group('select', () {
    test('changes the theme, notifies and saves it', () async {
      final store = InMemoryLocalStore();
      final controller = _controller(store);
      var notified = 0;
      controller.addListener(() => notified++);

      await controller.select(ThemeChoice.light);

      expect(controller.current, ThemeChoice.light);
      expect(notified, 1);
      expect(await store.read(ThemeController.storeKey), 'light');
    });

    test('a choice survives a restart', () async {
      final store = InMemoryLocalStore();
      await _controller(store).select(ThemeChoice.coffee);

      final restarted = _controller(store);
      await restarted.load();

      expect(restarted.current, ThemeChoice.coffee);
    });

    test('selecting the current theme does not notify', () async {
      final controller = _controller(InMemoryLocalStore());
      var notified = 0;
      controller.addListener(() => notified++);

      await controller.select(ThemeChoice.dark);

      expect(notified, 0);
    });

    test('a failed save still changes the theme, then throws', () async {
      final controller = _controller(
        InMemoryLocalStore(failure: const LocalStoreException('disk full')),
      );

      await expectLater(
        controller.select(ThemeChoice.light),
        throwsA(isA<LocalStoreException>()),
      );

      expect(controller.current, ThemeChoice.light);
    });
  });

  group('ThemeChoice.parse', () {
    test('finds a theme by name, ignoring case', () {
      expect(ThemeChoice.parse('Coffee'), ThemeChoice.coffee);
      expect(ThemeChoice.parse('DARK'), ThemeChoice.dark);
    });

    test('is null for anything else', () {
      expect(ThemeChoice.parse('neon'), isNull);
      expect(ThemeChoice.parse(''), isNull);
    });
  });
}
