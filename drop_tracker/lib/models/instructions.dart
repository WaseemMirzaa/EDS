/// Special-instruction flags attached to a medication, plus free-text notes.
class Instructions {
  final bool shake;
  final bool refrigerate;
  final bool wait5min;
  final bool removeContacts;
  final bool pressTearDuct;
  final String notes;

  const Instructions({
    this.shake = false,
    this.refrigerate = false,
    this.wait5min = false,
    this.removeContacts = false,
    this.pressTearDuct = false,
    this.notes = '',
  });

  Instructions copyWith({
    bool? shake,
    bool? refrigerate,
    bool? wait5min,
    bool? removeContacts,
    bool? pressTearDuct,
    String? notes,
  }) =>
      Instructions(
        shake: shake ?? this.shake,
        refrigerate: refrigerate ?? this.refrigerate,
        wait5min: wait5min ?? this.wait5min,
        removeContacts: removeContacts ?? this.removeContacts,
        pressTearDuct: pressTearDuct ?? this.pressTearDuct,
        notes: notes ?? this.notes,
      );

  /// Human-readable list of the checked instructions, in display order.
  List<String> get summary {
    final parts = <String>[];
    if (shake) parts.add('Shake bottle');
    if (refrigerate) parts.add('Refrigerate');
    if (wait5min) parts.add('Wait 5 min between drops');
    if (removeContacts) parts.add('Remove contacts');
    if (pressTearDuct) parts.add('Press tear duct');
    return parts;
  }

  Map<String, dynamic> toJson() => {
        'shake': shake,
        'refrigerate': refrigerate,
        'wait_5_min': wait5min,
        'remove_contacts': removeContacts,
        'press_tear_duct': pressTearDuct,
        'notes': notes,
      };

  factory Instructions.fromJson(Map<String, dynamic>? j) {
    j ??= const {};
    return Instructions(
      shake: j['shake'] == true,
      refrigerate: j['refrigerate'] == true,
      wait5min: j['wait_5_min'] == true,
      removeContacts: j['remove_contacts'] == true,
      pressTearDuct: j['press_tear_duct'] == true,
      notes: (j['notes'] ?? '') as String,
    );
  }
}
