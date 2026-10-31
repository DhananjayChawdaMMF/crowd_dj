import 'dart:ui_web' as ui_web;

/// just_audio_web cannot read `asset:///` URIs, so bundled audio is loaded by
/// URL. The asset manager honours the app's base href (sub-path deployments).
String? resolveAssetUrl(String assetPath) =>
    ui_web.assetManager.getAssetUrl(assetPath);
