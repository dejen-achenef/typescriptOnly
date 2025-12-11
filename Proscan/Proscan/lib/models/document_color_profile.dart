enum DocumentColorProfile {
  color('color'),
  grayscale('grayscale'),
  blackWhite('black_white'),
  magic('magic');

  const DocumentColorProfile(this.key);
  final String key;

  static DocumentColorProfile fromKey(String? raw) {
    if (raw == null || raw.isEmpty) return DocumentColorProfile.color;
    return DocumentColorProfile.values.firstWhere(
      (profile) => profile.key == raw,
      orElse: () => DocumentColorProfile.color,
    );
  }
}

extension DocumentColorProfileX on DocumentColorProfile {
  String get label => switch (this) {
        DocumentColorProfile.color => 'Color',
        DocumentColorProfile.grayscale => 'Grayscale',
        DocumentColorProfile.blackWhite => 'B & W',
        DocumentColorProfile.magic => 'Magic',
      };
}

