class SoundOption {
  const SoundOption({
    required this.id,
    required this.name,
    this.asset,
    this.file,
    this.raw,
  });

  final String id;
  final String name;

  /// Path relatif terhadap folder `assets/`, misal `sound/coin.wav`.
  final String? asset;

  /// Path absolut berkas yang diimpor pengguna.
  final String? file;

  /// Nama resource di `android/app/src/main/res/raw` tanpa ekstensi.
  /// Hanya suara bawaan yang bisa dipakai sebagai nada notifikasi.
  final String? raw;

  bool get isSilent => asset == null && file == null;

  bool get canNotify => raw != null;

  static const silent = SoundOption(id: 'none', name: 'Diam');

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'file': file};

  factory SoundOption.fromJson(Map<String, Object?> json) => SoundOption(
    id: json['id'] as String,
    name: json['name'] as String,
    file: json['file'] as String?,
  );
}

class SoundLibrary {
  SoundLibrary._();

  static const builtIn = <SoundOption>[
    SoundOption(
      id: 'asset:coin.wav',
      name: 'Koin',
      asset: 'sound/coin.wav',
      raw: 'coin',
    ),
    SoundOption(
      id: 'asset:chime.wav',
      name: 'Lonceng',
      asset: 'sound/chime.wav',
      raw: 'chime',
    ),
    SoundOption(
      id: 'asset:pop.wav',
      name: 'Pop',
      asset: 'sound/pop.wav',
      raw: 'pop',
    ),
    SoundOption(
      id: 'asset:down.wav',
      name: 'Turun',
      asset: 'sound/down.wav',
      raw: 'down',
    ),
  ];

  static List<SoundOption> get notifiable =>
      builtIn.where((option) => option.canNotify).toList(growable: false);

  static SoundOption resolve(
    String id,
    List<SoundOption> imported, {
    SoundOption? fallback,
  }) {
    if (id == SoundOption.silent.id) return SoundOption.silent;
    for (final option in builtIn) {
      if (option.id == id) return option;
    }
    for (final option in imported) {
      if (option.id == id) return option;
    }
    return fallback ?? builtIn.first;
  }
}
