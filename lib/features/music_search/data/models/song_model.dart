import '../../domain/song.dart';

Song songFromJson(Map<String, dynamic> j) => Song(
  id: j['id'] as String,
  provider: j['provider'] as String? ?? '',
  providerSongId: j['provider_song_id'] as String? ?? '',
  title: j['title'] as String,
  artist: j['artist'] as String,
  albumName: j['album_name'] as String?,
  artworkUrl: j['artwork_url'] as String?,
  durationMs: (j['duration_ms'] as num?)?.toInt(),
);
