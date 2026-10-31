# Music providers and licensing

## Architecture
The UI and the player depend on interfaces, never on a vendor SDK (`lib/features/music_search/domain`, `music_player/domain`):

| Interface | Purpose |
|---|---|
| `MusicProvider` | `searchSongs(query)`, `getSongDetails(id)`, `getPlayableSource(id)`; `id`, `displayName`, `isDemo` |
| `SongSearchRepository` | what the search UI uses; wraps a provider |
| `AudioPlaybackService` | host-only engine: load, play, pause, seek, stop, position, duration, state stream |

The only provider today is `MockMusicProvider` (12 sample entries titled "(Demo)", no artwork). Its audio is 12 original 24-second tracks synthesised for this project and bundled as same-origin assets, so there is no third-party licence and no CORS issue. The guest UI states that the catalog is sample data. To switch providers change the one registration in `lib/core/services/app_services.dart`.

## What a real provider must satisfy
1. **Credentials stay server-side.** Call vendor APIs from a Supabase Edge Function; the Flutter client only calls your function with the user's session. Never put vendor secrets in `env/*.json` or `--dart-define`.
2. **Metadata should be resolved server-side too.** The `recommend_song` function validates and bounds client-supplied metadata, and songs are per room, but a member can still mislabel their own room's requests. An Edge Function that looks the song up by id and returns trusted metadata closes that gap (then change `recommend_song` to accept only a provider id).
3. **Only legally playable audio.** `getPlayableSource` must return `null` for anything the provider does not license for this use. Do not scrape, proxy or re-host audio you are not licensed to stream.
4. **Browser playback constraints.** `just_audio` on web uses an HTML audio element: the URL needs CORS headers (or same origin), a browser-supported codec (MP3/AAC are the safest; OGG Vorbis is not supported by every Safari), and the first `play()` needs a user gesture (the DJ's click; the app asks for one if the browser blocks it). Add the audio host to `media-src` / `connect-src` in `tool/hosting.py`, then regenerate the hosting config.
5. **Rights holders' terms.** Public performance and streaming rights differ from personal listening. A room played to an audience may need licences even when the provider's API allows playback.

## Options (verify each provider's current terms before building)
| Source | Search | Full-track playback in this web app | Notes |
|---|---|---|---|
| Own / royalty-free / Creative Commons audio you host | your catalog | Yes | Simplest compliant path; record licence per track |
| Catalogs with open or CC licensing and a streaming API (for example Jamendo, Audius) | yes | Generally yes, subject to each API's attribution and usage terms | Check commercial-use flags per track |
| Spotify | Web API for metadata/search | No for a custom player. Playback is limited to Spotify's own SDK (Premium listener, no re-streaming to an audience) | Use for search/metadata only if their terms allow your use; it does not give you an audio URL |
| YouTube | Data API for search | Only through the official embedded player, with the player visible and ads/terms intact | Not an audio source for `just_audio`; would need a different player implementation |
| Apple Music | Catalog API | Playback via MusicKit JS for subscribers only | Same limitation: not an arbitrary audio URL |

If the product requirement is "play anything from a mainstream streaming service for a room", that cannot be done with an unrestricted audio URL; the compliant alternatives are a licensed catalog, the provider's own playback SDK per listener, or uploads the DJ has rights to.

## Adding a provider
1. Implement `MusicProvider` (HTTP calls go to your Edge Function; add `dio` then).
2. Return `PlayableSource(url: ...)` only for licensed audio.
3. Register it in `AppServices`; update `hosting.py` CSP (`media-src`, `connect-src`) and re-run `python3 tool/hosting.py`.
4. Add contract tests mirroring `test/phase4_logic_test.dart` (search, details, playable source, unknown ids).
5. Update `recommend_song` if you move metadata resolution server-side.
