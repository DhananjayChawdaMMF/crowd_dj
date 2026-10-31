import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the production web shell and hosting config (see tool/hosting.py).
void main() {
  Map<String, dynamic> json(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  group('manifest and icons', () {
    final manifest = json('web/manifest.json');

    test('is branded, dark and installable', () {
      expect(manifest['name'], 'CrowdDJ');
      expect(manifest['short_name'], 'CrowdDJ');
      expect(manifest['theme_color'], '#0B0B12');
      expect(manifest['background_color'], '#0B0B12');
      expect(manifest['display'], 'standalone');
      expect(manifest['start_url'], '/');
    });

    test('every declared icon exists and has a maskable variant', () {
      final icons = (manifest['icons'] as List).cast<Map<String, dynamic>>();
      for (final icon in icons) {
        expect(
          File('web/${icon['src']}').existsSync(),
          isTrue,
          reason: icon['src'] as String,
        );
      }
      expect(icons.where((i) => i['purpose'] == 'maskable'), isNotEmpty);
      expect(File('web/favicon.png').existsSync(), isTrue);
      expect(File('web/icons/apple-touch-icon.png').existsSync(), isTrue);
    });
  });

  group('index.html', () {
    final html = File('web/index.html').readAsStringSync();

    test('has the metadata a production page needs', () {
      expect(html, contains('<html lang="en">'));
      expect(
        html,
        isNot(contains('name="viewport"')),
      ); // Flutter injects its own
      expect(html, contains('name="theme-color"'));
      expect(html, contains(r'<base href="$FLUTTER_BASE_HREF">'));
      expect(html, contains('<title>CrowdDJ'));
    });

    test(
      'has no inline scripts, so a strict CSP (no unsafe-inline scripts) works',
      () {
        final scripts = RegExp(
          r'<script\b[^>]*>',
          caseSensitive: false,
        ).allMatches(html).map((m) => m.group(0)!);
        expect(scripts, isNotEmpty);
        for (final tag in scripts) {
          expect(tag, contains('src='), reason: 'inline script: $tag');
        }
      },
    );
  });

  group('robots.txt', () {
    test('keeps private rooms out of search engines', () {
      final robots = File('web/robots.txt').readAsStringSync();
      expect(robots, contains('Disallow: /room/'));
    });
  });

  group('hosting config', () {
    String headerValue(List headers, String key) =>
        (headers.cast<Map<String, dynamic>>().firstWhere(
              (h) => h['key'] == key,
            )['value']
            as String);

    test('firebase: deep links rewrite to the app shell', () {
      final hosting = json('firebase.json')['hosting'] as Map<String, dynamic>;
      expect(hosting['public'], 'build/web');
      final rewrite = (hosting['rewrites'] as List).single as Map;
      expect(rewrite['source'], '**');
      expect(rewrite['destination'], '/index.html');
    });

    test('firebase: security headers and cache policy', () {
      final hosting = json('firebase.json')['hosting'] as Map<String, dynamic>;
      final rules = (hosting['headers'] as List).cast<Map<String, dynamic>>();
      final all =
          rules.firstWhere((r) => r['source'] == '**')['headers'] as List;
      final csp = headerValue(all, 'Content-Security-Policy');
      expect(csp, contains("default-src 'self'"));
      expect(csp, contains("frame-ancestors 'none'"));
      expect(csp, contains('https://*.supabase.co'));
      expect(csp, contains('wss://*.supabase.co'));
      expect(csp, isNot(contains("'unsafe-eval'")));
      expect(headerValue(all, 'X-Content-Type-Options'), 'nosniff');
      expect(headerValue(all, 'X-Frame-Options'), 'DENY');

      // Entry files must always revalidate: they are not content-hashed.
      for (final f in [
        '/index.html',
        '/main.dart.js',
        '/flutter_bootstrap.js',
      ]) {
        final rule = rules.firstWhere((r) => r['source'] == f);
        expect(
          headerValue(rule['headers'] as List, 'Cache-Control'),
          'no-cache',
        );
      }
    });

    test('vercel and netlify serve the app shell for deep links', () {
      final vercel = json('vercel.json');
      final rewrite = (vercel['rewrites'] as List).single as Map;
      expect(rewrite['destination'], '/index.html');
      // A real room URL must hit the rewrite; real files must not.
      final pattern = RegExp('^${rewrite['source']}\$');
      expect(pattern.hasMatch('/room/ABC1234567/dj'), isTrue);
      expect(pattern.hasMatch('/create-room'), isTrue);
      expect(pattern.hasMatch('/main.dart.js'), isFalse);
      expect(pattern.hasMatch('/assets/assets/audio/demo-001.mp3'), isFalse);

      final netlify = File('netlify.toml').readAsStringSync();
      expect(netlify, contains('to = "/index.html"'));
      expect(netlify, contains('status = 200'));
    });
  });

  test('fonts: four static subsets, no variable font in the bundle', () {
    for (final w in [400, 600, 700, 800]) {
      final f = File('assets/fonts/InterTight-$w.ttf');
      expect(f.existsSync(), isTrue);
      expect(f.lengthSync(), lessThan(100 * 1024));
    }
    expect(File('assets/fonts/InterTight.ttf').existsSync(), isFalse);
    expect(File('assets/fonts/OFL.txt').existsSync(), isTrue);
  });
}
