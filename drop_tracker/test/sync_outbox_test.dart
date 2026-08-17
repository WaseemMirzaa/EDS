import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drop_tracker/data/remote/sync_outbox.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SyncOutbox', () {
    test('starts empty and persists an enqueued entry across loads', () async {
      final prefs = await SharedPreferences.getInstance();
      final outbox = await SyncOutbox.load(prefs);
      expect(outbox.isEmpty, isTrue);

      await outbox.enqueueMedicationDelete('med-1');
      expect(outbox.length, 1);

      // A fresh instance backed by the same prefs must see the same queue —
      // this is what makes the queue survive an app relaunch.
      final reloaded = await SyncOutbox.load(prefs);
      expect(reloaded.length, 1);
    });

    test('a second enqueue for the same entity replaces the first', () async {
      final prefs = await SharedPreferences.getInstance();
      final outbox = await SyncOutbox.load(prefs);

      final row = {'id': 'med-1', 'user_id': 'u1', 'name': 'Vigamox'};
      final rowV2 = {'id': 'med-1', 'user_id': 'u1', 'name': 'Vigamox (updated)'};

      await outbox.enqueueMedication(row, []);
      await outbox.enqueueMedication(rowV2, []);

      // Only the latest version should be queued — replaying a stale upsert
      // ahead of the current one would be a real (if harmless) correctness
      // smell, not just wasted work.
      expect(outbox.length, 1);
      final reloaded = await SyncOutbox.load(prefs);
      expect(reloaded.length, 1);
    });

    test('different entities queue independently', () async {
      final prefs = await SharedPreferences.getInstance();
      final outbox = await SyncOutbox.load(prefs);

      await outbox.enqueueMedicationDelete('med-1');
      await outbox.enqueueMedicationDelete('med-2');
      await outbox.enqueueDoseEvent({'id': 'evt-1', 'user_id': 'u1'});

      expect(outbox.length, 3);
    });

    test('flush with no backend configured leaves the queue intact', () async {
      // No Supabase.initialize() has run in this test process, so every
      // SupabaseSync...Raw() call throws — flush() must treat that as "not
      // yet delivered" and stop, never as success, and never crash the app.
      final prefs = await SharedPreferences.getInstance();
      final outbox = await SyncOutbox.load(prefs);
      await outbox.enqueueMedicationDelete('med-1');

      await outbox.flush();

      expect(outbox.length, 1);
    });

    test('flush is a no-op on an empty queue', () async {
      final prefs = await SharedPreferences.getInstance();
      final outbox = await SyncOutbox.load(prefs);
      await outbox.flush(); // must not throw
      expect(outbox.isEmpty, isTrue);
    });
  });
}
