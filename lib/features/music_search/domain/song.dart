class Song {
  const Song({
    required this.id,
    this.provider = '',
    this.providerSongId = '',
    required this.title,
    required this.artist,
    this.albumName,
    this.artworkUrl,
    this.durationMs,
  });

  final String id;
  final String provider;
  final String providerSongId;
  final String title;
  final String artist;
  final String? albumName;
  final String? artworkUrl;
  final int? durationMs;
}
