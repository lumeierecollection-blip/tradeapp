/// The fixed set of review tags a closed trade can carry. Deliberately small and
/// applied by hand — no auto-classification, no scoring.
enum MistakeTag {
  earlyEntry('early-entry', 'Entered too early'),
  lateEntry('late-entry', 'Chased the entry'),
  oversized('oversized', 'Position too big'),
  movedStop('moved-stop', 'Moved or widened the stop'),
  chasedPump('chased-pump', 'Bought into a spike'),
  ignoredInvalidation('ignored-invalidation', 'Held past the invalidation'),
  tradedIntoNews('traded-into-news', 'Open across a known event'),
  good('good', 'Clean, by-the-plan trade');

  final String id;
  final String label;
  const MistakeTag(this.id, this.label);

  static MistakeTag? fromId(String id) {
    for (final tag in values) {
      if (tag.id == id) return tag;
    }
    return null;
  }

  /// Human label for a stored tag id, falling back to the raw id.
  static String labelFor(String id) => fromId(id)?.label ?? id;
}
