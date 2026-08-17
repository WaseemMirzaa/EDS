import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_sync.dart';

enum OutboxOpType { upsertProfile, upsertMedication, deleteMedication, upsertDoseEvent }

/// One background push that hasn't confirmed yet.
///
/// [payload] is the exact table row (or, for a medication, `{row, taperRows}`)
/// as built by [SupabaseSync] at the moment the push was first attempted — not
/// the app's local model. Replaying an entry never re-derives anything (like
/// the device's current timezone for a profile row); it resends precisely what
/// was true when the mutation happened.
class OutboxEntry {
  final OutboxOpType type;
  final String entityId;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  const OutboxEntry({
    required this.type,
    required this.entityId,
    required this.payload,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'entity_id': entityId,
        'payload': payload,
        'created_at': createdAt.toIso8601String(),
      };

  factory OutboxEntry.fromJson(Map<String, dynamic> j) => OutboxEntry(
        type: OutboxOpType.values.firstWhere((t) => t.name == j['type']),
        entityId: (j['entity_id'] ?? '') as String,
        payload: (j['payload'] as Map).cast<String, dynamic>(),
        createdAt: DateTime.tryParse((j['created_at'] ?? '') as String) ??
            DateTime.now(),
      );
}

/// Persisted retry queue for background pushes to Supabase that failed —
/// typically because the device was offline at the moment a medication was
/// saved or a dose was logged.
///
/// The local cache (SharedPreferences, in [DropStore]) is already the source
/// of truth for what the UI shows, so nothing here is on the critical path for
/// correctness — a queued entry only affects how soon *other* devices and the
/// Doctor Report see the change. What matters is that a failed push is never
/// silently dropped: it's written to disk immediately, alongside the same
/// local save that already succeeded, and retried until it confirms.
///
/// Processed strictly in order and stops at the first failure rather than
/// skipping ahead — a failure almost always means "no connectivity right
/// now", and preserving order matters for entries that are second-and-later
/// edits to the very same medication.
class SyncOutbox {
  static const _key = 'droptracker_sync_outbox';

  final SharedPreferences _prefs;
  final List<OutboxEntry> _entries;
  bool _flushing = false;

  SyncOutbox._(this._prefs, this._entries);

  static Future<SyncOutbox> load(SharedPreferences prefs) async {
    final raw = prefs.getString(_key);
    var entries = <OutboxEntry>[];
    if (raw != null) {
      try {
        entries = (jsonDecode(raw) as List)
            .cast<Map<String, dynamic>>()
            .map(OutboxEntry.fromJson)
            .toList();
      } catch (_) {}
    }
    return SyncOutbox._(prefs, entries);
  }

  int get length => _entries.length;
  bool get isEmpty => _entries.isEmpty;

  Future<void> _persist() =>
      _prefs.setString(_key, jsonEncode(_entries.map((e) => e.toJson()).toList()));

  /// Queues a push for later. An unconfirmed entry already queued for the
  /// same [entityId] and [type] is replaced rather than appended — e.g.
  /// editing a medication twice while offline retries the *latest* version
  /// once, rather than replaying a now-superseded upsert first.
  Future<void> _enqueue(OutboxEntry entry) async {
    _entries.removeWhere(
        (e) => e.type == entry.type && e.entityId == entry.entityId);
    _entries.add(entry);
    await _persist();
  }

  Future<void> enqueueProfile(Map<String, dynamic> row) => _enqueue(OutboxEntry(
        type: OutboxOpType.upsertProfile,
        entityId: 'profile', // singleton per account
        payload: row,
        createdAt: DateTime.now(),
      ));

  Future<void> enqueueMedication(
    Map<String, dynamic> row,
    List<Map<String, dynamic>> taperRows,
  ) =>
      _enqueue(OutboxEntry(
        type: OutboxOpType.upsertMedication,
        entityId: row['id'] as String,
        payload: {'row': row, 'taper_rows': taperRows},
        createdAt: DateTime.now(),
      ));

  Future<void> enqueueMedicationDelete(String id) => _enqueue(OutboxEntry(
        type: OutboxOpType.deleteMedication,
        entityId: id,
        payload: const {},
        createdAt: DateTime.now(),
      ));

  Future<void> enqueueDoseEvent(Map<String, dynamic> row) => _enqueue(OutboxEntry(
        type: OutboxOpType.upsertDoseEvent,
        entityId: row['id'] as String,
        payload: row,
        createdAt: DateTime.now(),
      ));

  /// Attempts every queued entry, in order, stopping at the first failure.
  /// Safe to call opportunistically and often — a no-op when already
  /// flushing or when the queue is empty.
  Future<void> flush() async {
    if (_flushing || _entries.isEmpty) return;
    _flushing = true;
    try {
      while (_entries.isNotEmpty) {
        final entry = _entries.first;
        final ok = await _replay(entry);
        if (!ok) break;
        _entries.removeAt(0);
        await _persist();
      }
    } finally {
      _flushing = false;
    }
  }

  Future<bool> _replay(OutboxEntry entry) async {
    try {
      switch (entry.type) {
        case OutboxOpType.upsertProfile:
          await SupabaseSync.pushProfileRaw(entry.payload);
        case OutboxOpType.upsertMedication:
          await SupabaseSync.pushMedicationRaw(
            (entry.payload['row'] as Map).cast<String, dynamic>(),
            ((entry.payload['taper_rows'] as List?) ?? const [])
                .map((r) => (r as Map).cast<String, dynamic>())
                .toList(),
          );
        case OutboxOpType.deleteMedication:
          await SupabaseSync.deleteMedicationRaw(entry.entityId);
        case OutboxOpType.upsertDoseEvent:
          await SupabaseSync.pushDoseEventRaw(entry.payload);
      }
      return true;
    } catch (e) {
      debugPrint('SyncOutbox: retry deferred for ${entry.type.name} '
          '${entry.entityId} — $e');
      return false;
    }
  }
}
