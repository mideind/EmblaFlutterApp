// SpotifyClient and the music tools, against a scripted Web API.

import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;

import 'package:embla/spotify_client.dart';
import 'package:embla/tools/device_tools.dart' show spotifyTools;
import 'package:embla/tools/spotify_tools.dart';
import 'package:embla/tools/tool.dart';

import 'device_tools_test.dart' show FakeDeviceActions;

void main() {
  final ToolContext ctx = ToolContext(now: DateTime(2026, 9, 4, 12));

  /// A client whose HTTP goes to [handle], with tokens in [prefs].
  SpotifyClient client(Map<String, String?> prefs, FakeDeviceActions actions,
      Future<http.Response> Function(http.Request req, List<http.Request> seen) handle,
      {List<http.Request>? seen}) {
    final List<http.Request> log = seen ?? <http.Request>[];
    return SpotifyClient(
      clientID: 'cid',
      clientSecret: 'secret',
      actions: actions,
      readPref: (String k) => prefs[k],
      writePref: (String k, String? v) => v == null ? prefs.remove(k) : prefs[k] = v,
      now: () => DateTime(2026, 9, 4, 12),
      client: MockClient((http.Request req) {
        log.add(req);
        return handle(req, log);
      }),
    );
  }

  http.Response json(Object body, [int status = 200]) => http.Response(jsonEncode(body), status);
  http.Response tokenResponse() =>
      json(<String, Object>{'access_token': 'tok', 'expires_in': 3600, 'refresh_token': 'r2'});

  test('connect runs PKCE through the login sheet and stores the tokens', () async {
    final Map<String, String?> prefs = <String, String?>{};
    final FakeDeviceActions actions = FakeDeviceActions();
    final List<http.Request> seen = <http.Request>[];
    final SpotifyClient c = client(prefs, actions, (req, _) async => tokenResponse(), seen: seen);

    expect(c.isConnected, isFalse);
    await c.connect();

    final Uri authorize = actions.calls.single.$2['url'] as Uri;
    expect(authorize.host, 'accounts.spotify.com');
    expect(authorize.queryParameters['code_challenge_method'], 'S256');
    expect(authorize.queryParameters['redirect_uri'], kSpotifyRedirectUri);
    // The code from the callback and the verifier go to the token endpoint.
    final Map<String, String> body = Uri.splitQueryString(seen.single.body);
    expect(body['grant_type'], 'authorization_code');
    expect(body['code'], 'abc');
    expect(body['code_verifier'], isNotEmpty);
    expect(prefs[kSpotifyRefreshTokenKey], 'r2');
    expect(c.isConnected, isTrue);
  });

  test('a stale access token is refreshed before use', () async {
    final Map<String, String?> prefs = <String, String?>{
      kSpotifyRefreshTokenKey: 'r1',
      kSpotifyAccessTokenKey: 'old',
      kSpotifyTokenExpiryKey: '0',
    };
    final SpotifyClient c = client(prefs, FakeDeviceActions(), (req, seen) async {
      if (req.url.host == 'accounts.spotify.com') return tokenResponse();
      expect(req.headers['Authorization'], 'Bearer tok');
      return http.Response('', 204);
    });
    await c.next();
    expect(prefs[kSpotifyAccessTokenKey], 'tok');
  });

  test('a revoked refresh token is forgotten so settings can offer reconnecting', () async {
    final Map<String, String?> prefs = <String, String?>{
      kSpotifyRefreshTokenKey: 'r1',
      kSpotifyTokenExpiryKey: '0',
    };
    final SpotifyClient c = client(prefs, FakeDeviceActions(),
        (req, _) async => json(<String, String>{'error': 'invalid_grant'}, 400));
    await expectLater(c.pause(), throwsA(isA<SpotifyException>()));
    expect(c.isConnected, isFalse);
  });

  test('without a login the player says how to connect, without calling out', () async {
    final List<http.Request> seen = <http.Request>[];
    final SpotifyClient c = client(<String, String?>{}, FakeDeviceActions(),
        (req, _) async => http.Response('', 204), seen: seen);
    await expectLater(c.next(), throwsA(predicate((e) => '$e' == kSpotifyNotConnected)));
    expect(seen, isEmpty);
  });

  group('play_music', () {
    Future<http.Response> catalog(http.Request req, List<http.Request> seen) async {
      if (req.url.host == 'accounts.spotify.com') return tokenResponse();
      if (req.url.path == '/v1/search') {
        expect(req.url.queryParameters['q'], 'Lífið er lag Stuðmenn');
        expect(req.url.queryParameters['type'], 'track');
        return json(<String, Object>{
          'tracks': <String, Object>{
            // Search can return null entries; they must be skipped.
            'items': <Object?>[null, <String, String>{'uri': 'spotify:track:1'}]
          }
        });
      }
      if (req.url.path == '/v1/me/player/play') {
        expect(jsonDecode(req.body), <String, Object>{'uris': <String>['spotify:track:1']});
        return http.Response('', 204);
      }
      fail('unexpected ${req.method} ${req.url}');
    }

    test('plays on the active device and stays in Embla', () async {
      final FakeDeviceActions actions = FakeDeviceActions();
      final SpotifyClient c = client(<String, String?>{kSpotifyRefreshTokenKey: 'r1'}, actions, catalog);
      final ToolResult res = await PlayMusicTool(c).call(
          <String, dynamic>{'kind': 'track', 'title': 'Lífið er lag', 'artist': 'Stuðmenn'}, ctx);
      expect(res.ok, isTrue);
      expect(res.data['summary'], contains('Stuðmenn'));
      expect(res.endsTurn, isFalse);
      expect(actions.calls, isEmpty);
    });

    test('with no active device the Spotify app takes over and the turn ends', () async {
      final FakeDeviceActions actions = FakeDeviceActions();
      final SpotifyClient c = client(<String, String?>{kSpotifyRefreshTokenKey: 'r1'}, actions,
          (req, seen) => req.url.path == '/v1/me/player/play'
              ? Future.value(http.Response('', 404))
              : catalog(req, seen));
      final ToolResult res = await PlayMusicTool(c).call(
          <String, dynamic>{'kind': 'track', 'title': 'Lífið er lag', 'artist': 'Stuðmenn'}, ctx);
      expect(res.ok, isTrue);
      expect(res.endsTurn, isTrue);
      expect(actions.calls.single.$2['uri'], 'spotify:track:1');
    });

    test('a playlist prefers the user\'s own, matched loosely', () async {
      final SpotifyClient c = client(<String, String?>{kSpotifyRefreshTokenKey: 'r1'}, FakeDeviceActions(),
          (req, _) async {
        if (req.url.host == 'accounts.spotify.com') return tokenResponse();
        if (req.url.path == '/v1/me/playlists') {
          return json(<String, Object>{
            'items': <Object>[
              <String, String>{'name': 'Sumarið 2026', 'uri': 'spotify:playlist:own'},
            ]
          });
        }
        if (req.url.path == '/v1/me/player/play') {
          expect(jsonDecode(req.body), <String, String>{'context_uri': 'spotify:playlist:own'});
          return http.Response('', 204);
        }
        fail('unexpected ${req.url}');
      });
      final ToolResult res =
          await PlayMusicTool(c).call(<String, dynamic>{'kind': 'playlist', 'title': 'sumarið', 'artist': null}, ctx);
      expect(res.data['uri'], 'spotify:playlist:own');
    });

    test('nothing found is a failure the model can relay', () async {
      final SpotifyClient c = client(<String, String?>{}, FakeDeviceActions(), (req, _) async {
        if (req.url.host == 'accounts.spotify.com') return tokenResponse();
        return json(<String, Object>{'tracks': <String, Object>{'items': <Object>[]}});
      });
      final ToolResult res =
          await PlayMusicTool(c).call(<String, dynamic>{'kind': 'track', 'title': 'x', 'artist': null}, ctx);
      expect(res.ok, isFalse);
      expect(res.data['error'], contains('Fann ekki'));
    });
  });

  test('queue_music and control_music hit the player endpoints', () async {
    final List<http.Request> seen = <http.Request>[];
    final SpotifyClient c = client(<String, String?>{kSpotifyRefreshTokenKey: 'r1'}, FakeDeviceActions(),
        (req, _) async {
      if (req.url.host == 'accounts.spotify.com') return tokenResponse();
      if (req.url.path == '/v1/search') {
        return json(<String, Object>{'tracks': <String, Object>{'items': <Object>[<String, String>{'uri': 'spotify:track:9'}]}});
      }
      return http.Response('', 204);
    }, seen: seen);

    await QueueMusicTool(c).call(<String, dynamic>{'title': 'hæ', 'artist': null}, ctx);
    await ControlMusicTool(c).call(<String, dynamic>{'command': 'pause'}, ctx);
    final ToolResult bad = await ControlMusicTool(c).call(<String, dynamic>{'command': 'louder'}, ctx);

    final List<String> player = seen
        .where((r) => r.url.path.startsWith('/v1/me/player/'))
        .map((r) => '${r.method} ${r.url.path}${r.url.hasQuery ? '?${r.url.query}' : ''}')
        .toList();
    expect(player, <String>['POST /v1/me/player/queue?uri=spotify%3Atrack%3A9', 'PUT /v1/me/player/pause']);
    expect(bad.ok, isFalse);
  });

  test('no active device is explained, not thrown', () async {
    final SpotifyClient c = client(<String, String?>{kSpotifyRefreshTokenKey: 'r1'}, FakeDeviceActions(),
        (req, _) async => req.url.host == 'accounts.spotify.com' ? tokenResponse() : http.Response('', 404));
    final ToolResult res = await ControlMusicTool(c).call(<String, dynamic>{'command': 'next'}, ctx);
    expect(res.ok, isFalse);
    expect(res.data['error'], kSpotifyNoDevice);
  });

  test('without a client ID the model is not offered music at all', () {
    final SpotifyClient unconfigured = SpotifyClient(clientID: '', clientSecret: '', actions: FakeDeviceActions(),
        readPref: (_) => null, writePref: (_, __) {});
    expect(spotifyTools(unconfigured), isEmpty);
    expect(spotifyTools(client(<String, String?>{}, FakeDeviceActions(), (r, _) async => http.Response('', 204))),
        hasLength(3));
  });
}
