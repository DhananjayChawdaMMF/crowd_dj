import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/room/data/room_remote_data_source.dart';
import '../../features/room/data/room_repository_impl.dart';
import '../../features/room/domain/room_repository.dart';
import '../../features/queue/data/queue_repository_impl.dart';
import '../../features/queue/domain/queue_repository.dart';
import '../../features/recommendations/data/recommendation_repository_impl.dart';
import '../../features/recommendations/domain/recommendation_repository.dart';
import '../../features/music_search/data/mock_music_provider.dart';
import '../../features/music_search/data/song_search_repository_impl.dart';
import '../../features/music_search/domain/music_provider.dart';
import '../../features/music_search/domain/song_search_repository.dart';
import '../../features/music_player/data/playback_repository_impl.dart';
import '../../features/music_player/domain/playback_repository.dart';
import '../../features/room/data/supabase_room_realtime.dart';
import '../../features/room/domain/room_realtime.dart';
import 'server_clock.dart';
import 'session_provider.dart';
import 'supabase_session_provider.dart';

/// App-lifetime dependencies. Registered once at startup, after Supabase init.
abstract final class AppServices {
  static void register() {
    final client = Supabase.instance.client;
    Get.put<SessionProvider>(
      SupabaseSessionProvider(client.auth),
      permanent: true,
    );
    Get.put<RoomRepository>(
      RoomRepositoryImpl(RoomRemoteDataSource(client)),
      permanent: true,
    );
    // Swap this one line for a real provider (backed by an Edge Function).
    Get.put<MusicProvider>(const MockMusicProvider(), permanent: true);
    Get.put<SongSearchRepository>(
      SongSearchRepositoryImpl(Get.find<MusicProvider>()),
      permanent: true,
    );
    Get.put<PlaybackRepository>(
      PlaybackRepositoryImpl(client),
      permanent: true,
    );
    Get.put<RoomRealtime>(SupabaseRoomRealtime(client), permanent: true);
    Get.put<ServerClock>(
      ServerClock(
        fetchServerTime: () async {
          final value = await client.rpc('server_time');
          return DateTime.parse(value as String);
        },
      ),
      permanent: true,
    );
    Get.put<QueueRepository>(QueueRepositoryImpl(client), permanent: true);
    Get.put<RecommendationRepository>(
      RecommendationRepositoryImpl(client),
      permanent: true,
    );
  }
}
