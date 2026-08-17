import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_bootstrap.dart';

/// Live cross-device sync: subscribes to Postgres changes on this user's own
/// rows and calls back whenever something changes server-side that didn't
/// originate from this device — a medication added on a tablet should appear
/// on the phone without the user reopening the app.
///
/// Deliberately coarse-grained rather than delivering row-level deltas: on any
/// change to `medications` / `taper_steps`, [onMedicationsChanged] fires; on
/// any change to `dose_events`, [onDoseEventsChanged] fires; on any change to
/// `profiles`, [onProfileChanged] fires. Each callback is expected to re-pull
/// that whole slice via [SupabaseSync] and replace local state. For a single
/// user's own data — at most a few dozen medications and doses — a full
/// re-pull is simpler and just as cheap as reconciling individual row events,
/// and it can't drift from the server's actual state the way a hand-rolled
/// per-row merge eventually would.
///
/// Security is enforced the same way as every other read: Realtime authorizes
/// each change against the subscriber's row-level security policies before
/// delivering it, so no explicit `user_id` filter is required for
/// `taper_steps` (which has no such column of its own — only a join to
/// `medications`) to still only ever deliver this user's own steps.
class SupabaseRealtime {
  SupabaseRealtime._();
  static SupabaseRealtime? _instance;

  RealtimeChannel? _channel;
  Timer? _medDebounce;
  Timer? _eventDebounce;

  /// Coalesces a burst of related events (a medication upsert immediately
  /// followed by its taper_steps replace, for instance) into one re-pull
  /// instead of one per row changed.
  static const _debounce = Duration(milliseconds: 400);

  static SupabaseRealtime get instance => _instance ??= SupabaseRealtime._();

  /// Starts listening for the given account. Safe to call again with a new
  /// [userId] — the previous subscription is torn down first.
  void start({
    required String userId,
    required VoidCallback onMedicationsChanged,
    required VoidCallback onDoseEventsChanged,
    required VoidCallback onProfileChanged,
  }) {
    stop();

    final client = SupabaseBootstrap.client;
    final channel = client.channel('account-sync-$userId');

    void debouncedMeds() {
      _medDebounce?.cancel();
      _medDebounce = Timer(_debounce, onMedicationsChanged);
    }

    void debouncedEvents() {
      _eventDebounce?.cancel();
      _eventDebounce = Timer(_debounce, onDoseEventsChanged);
    }

    channel
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'medications',
        callback: (_) => debouncedMeds(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'taper_steps',
        callback: (_) => debouncedMeds(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'dose_events',
        callback: (_) => debouncedEvents(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'profiles',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: userId,
        ),
        callback: (_) => onProfileChanged(),
      )
      ..subscribe();

    _channel = channel;
  }

  void stop() {
    _medDebounce?.cancel();
    _eventDebounce?.cancel();
    _medDebounce = null;
    _eventDebounce = null;
    final ch = _channel;
    _channel = null;
    if (ch != null) {
      SupabaseBootstrap.client.removeChannel(ch);
    }
  }
}
