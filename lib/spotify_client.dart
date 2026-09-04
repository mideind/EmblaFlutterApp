/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2026 Miðeind ehf. <mideind@mideind.is>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

// Spotify: the Web API for search, queue and player control, the Spotify app
// for starting playback. Ported from the embla-2.0 Swift MVP.
//
// Two tokens. Catalog search needs only the app's own client credentials.
// Anything about the user (their playlists, the queue, skip/pause/resume,
// playing on the active device) needs a user token from a one-time PKCE
// login in settings; the refresh token lives in Prefs.

import 'dart:convert' show base64Url, jsonDecode, jsonEncode, utf8;
import 'dart:math' show Random;

import 'package:crypto/crypto.dart' show sha256;
import 'package:http/http.dart' as http;

import './common.dart' show dlog;
import './prefs.dart' show Prefs;
import './tools/device_actions_channel.dart' show DeviceActions, DeviceActionsChannel;
import './util.dart' show readSpotifyClientID, readSpotifyClientSecret;

const String kSpotifyRedirectUri = 'embla://spotify';
const String kSpotifyCallbackScheme = 'embla';
const String kSpotifyScope =
    'user-modify-playback-state user-read-playback-state playlist-read-private';

const String kSpotifyRefreshTokenKey = 'spotify_refresh_token';
const String kSpotifyAccessTokenKey = 'spotify_access_token';
const String kSpotifyTokenExpiryKey = 'spotify_token_expiry';

const String kSpotifyNotConnected = 'Spotify er ekki tengt. Ýttu á „Tengja Spotify“ í stillingum.';
const String kSpotifyNoDevice = 'Ekkert virkt Spotify tæki. Spilaðu fyrst lag.';

class SpotifyException implements Exception {
  final String message;
  const SpotifyException(this.message);
  @override
  String toString() => message;
}

/// Injectable persistence for the tokens, so tests need no SharedPreferences.
typedef ReadPref = String? Function(String key);
typedef WritePref = void Function(String key, String? value);

class SpotifyClient {
  final String clientID;
  final String clientSecret;
  final http.Client _http;
  final DeviceActions _actions;
  final ReadPref _read;
  final WritePref _write;
  final DateTime Function() _now;

  /// Client-credentials token; only in memory, it is cheap to get again.
  String? _appToken;
  DateTime? _appTokenExpiry;

  SpotifyClient({
    required this.clientID,
    required this.clientSecret,
    http.Client? client,
    DeviceActions? actions,
    ReadPref? readPref,
    WritePref? writePref,
    DateTime Function()? now,
  })  : _http = client ?? http.Client(),
        _actions = actions ?? DeviceActionsChannel(),
        _read = readPref ?? Prefs().stringForKey,
        _write = writePref ?? _writePrefsKey,
        _now = now ?? DateTime.now;

  factory SpotifyClient.fromKeys({DeviceActions? actions}) => SpotifyClient(
      clientID: readSpotifyClientID(), clientSecret: readSpotifyClientSecret(), actions: actions);

  static void _writePrefsKey(String key, String? value) {
    if (value == null) {
      Prefs().remove(key);
    } else {
      Prefs().setStringForKey(key, value);
    }
  }

  /// False when no Spotify client ID was baked into the build.
  bool get isConfigured => clientID.isNotEmpty;

  /// True once the user has logged in from settings.
  bool get isConnected => _read(kSpotifyRefreshTokenKey) != null;

  // MARK: - User login (PKCE)

  /// One-time login: browser sheet, `embla://spotify` callback, token exchange.
  Future<void> connect() async {
    if (!isConfigured) {
      throw const SpotifyException('Vantar Spotify client ID');
    }
    final String verifier = _base64Url(List<int>.generate(64, (_) => Random.secure().nextInt(256)));
    final String challenge = _base64Url(sha256.convert(utf8.encode(verifier)).bytes);
    final Uri authorize = Uri.https('accounts.spotify.com', '/authorize', <String, String>{
      'client_id': clientID,
      'response_type': 'code',
      'redirect_uri': kSpotifyRedirectUri,
      'code_challenge_method': 'S256',
      'code_challenge': challenge,
      'scope': kSpotifyScope,
    });
    final Uri callback = await _actions.webAuth(url: authorize, callbackScheme: kSpotifyCallbackScheme);
    final String? code = callback.queryParameters['code'];
    if (code == null) {
      throw const SpotifyException('Spotify innskráning mistókst');
    }
    await _requestUserToken(<String, String>{
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': kSpotifyRedirectUri,
      'code_verifier': verifier,
    });
  }

  void disconnect() {
    _write(kSpotifyRefreshTokenKey, null);
    _write(kSpotifyAccessTokenKey, null);
    _write(kSpotifyTokenExpiryKey, null);
  }

  Future<String> _userToken() async {
    final String? refresh = _read(kSpotifyRefreshTokenKey);
    if (refresh == null) {
      throw const SpotifyException(kSpotifyNotConnected);
    }
    final String? token = _read(kSpotifyAccessTokenKey);
    final int expiry = int.tryParse(_read(kSpotifyTokenExpiryKey) ?? '') ?? 0;
    if (token != null && expiry > _now().millisecondsSinceEpoch) {
      return token;
    }
    return _requestUserToken(<String, String>{'grant_type': 'refresh_token', 'refresh_token': refresh});
  }

  Future<String> _requestUserToken(Map<String, String> params) async {
    final http.Response res = await _http.post(
      Uri.https('accounts.spotify.com', '/api/token'),
      headers: const <String, String>{'Content-Type': 'application/x-www-form-urlencoded'},
      body: <String, String>{...params, 'client_id': clientID},
    );
    final Map<String, dynamic> json = _json(res);
    final String? token = json['access_token'] as String?;
    if (token == null) {
      if (json['error'] == 'invalid_grant') {
        // Revoked or expired refresh token: forget it so settings offers to reconnect.
        disconnect();
        throw const SpotifyException('Spotify tengingin er útrunnin. Tengdu Spotify aftur í stillingum.');
      }
      throw SpotifyException('Spotify auðkenning mistókst: ${res.body}');
    }
    final int ttl = ((json['expires_in'] as num?) ?? 3600).toInt() - 60;
    _write(kSpotifyAccessTokenKey, token);
    _write(kSpotifyTokenExpiryKey, _now().add(Duration(seconds: ttl)).millisecondsSinceEpoch.toString());
    final String? refresh = json['refresh_token'] as String?;
    if (refresh != null) {
      _write(kSpotifyRefreshTokenKey, refresh);
    }
    return token;
  }

  // MARK: - Catalog (client credentials)

  Future<String> _appTokenValue() async {
    final String? cached = _appToken;
    if (cached != null && _appTokenExpiry!.isAfter(_now())) {
      return cached;
    }
    if (clientSecret.isEmpty) {
      throw const SpotifyException('Vantar Spotify client secret');
    }
    final http.Response res = await _http.post(
      Uri.https('accounts.spotify.com', '/api/token'),
      headers: <String, String>{
        'Authorization': 'Basic ${base64Url.encode(utf8.encode('$clientID:$clientSecret'))}',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: 'grant_type=client_credentials',
    );
    final Map<String, dynamic> json = _json(res);
    final String? token = json['access_token'] as String?;
    if (token == null) {
      throw SpotifyException('Spotify auðkenning mistókst: ${res.body}');
    }
    _appToken = token;
    _appTokenExpiry = _now().add(Duration(seconds: ((json['expires_in'] as num?) ?? 3600).toInt() - 60));
    return token;
  }

  /// First matching track's URI, or throws.
  Future<String> searchTrackUri({required String title, String? artist}) async {
    final Map<String, dynamic> json = await _search(
        <String>[title, if (artist != null) artist].join(' '), 'track', 1, await _appTokenValue());
    final String? uri = _firstUri(json['tracks']);
    if (uri == null) {
      throw SpotifyException('Fann ekki lagið „$title“ á Spotify');
    }
    return uri;
  }

  /// The user's own playlist of that name first, then the catalog.
  Future<String> playlistUri(String name) async {
    try {
      final String? own = await _ownPlaylistUri(name);
      if (own != null) {
        return own;
      }
    } on SpotifyException catch (e) {
      // Not connected: the catalog still works.
      dlog('Own playlists unavailable: $e');
    }
    final Map<String, dynamic> json = await _search(name, 'playlist', 5, await _appTokenValue());
    final String? uri = _firstUri(json['playlists']);
    if (uri == null) {
      throw SpotifyException('Fann ekki lagalistann „$name“ á Spotify');
    }
    return uri;
  }

  Future<String?> _ownPlaylistUri(String name) async {
    final http.Response res = await _http.get(
      Uri.https('api.spotify.com', '/v1/me/playlists', <String, String>{'limit': '50'}),
      headers: <String, String>{'Authorization': 'Bearer ${await _userToken()}'},
    );
    final List<dynamic> items = (_json(res)['items'] as List<dynamic>?) ?? const <dynamic>[];
    final String query = name.toLowerCase();
    String? nameOf(dynamic p) => (p as Map<String, dynamic>?)?['name'] as String?;
    final dynamic match = items.cast<dynamic>().firstWhere((p) => nameOf(p)?.toLowerCase() == query,
        orElse: () => items.firstWhere((p) => nameOf(p)?.toLowerCase().contains(query) == true,
            orElse: () => null));
    return (match as Map<String, dynamic>?)?['uri'] as String?;
  }

  Future<Map<String, dynamic>> _search(String q, String type, int limit, String token) async {
    final http.Response res = await _http.get(
      Uri.https('api.spotify.com', '/v1/search',
          <String, String>{'q': q, 'type': type, 'limit': '$limit', 'market': 'IS'}),
      headers: <String, String>{'Authorization': 'Bearer $token'},
    );
    return _json(res);
  }

  /// Search can return null entries in `items`, hence the per-element cast.
  static String? _firstUri(dynamic page) {
    final List<dynamic>? items = (page as Map<String, dynamic>?)?['items'] as List<dynamic>?;
    if (items == null) return null;
    for (final dynamic item in items) {
      final String? uri = (item as Map<String, dynamic>?)?['uri'] as String?;
      if (uri != null) return uri;
    }
    return null;
  }

  // MARK: - Playback (user token, or the Spotify app)

  /// Plays on the user's active device without leaving Embla. With no active
  /// device (or no login) the Spotify app is opened to play it instead.
  /// Returns true when the Spotify app was opened.
  Future<bool> play(String uri) async {
    try {
      final Map<String, dynamic> body = uri.contains(':track:')
          ? <String, dynamic>{'uris': <String>[uri]}
          : <String, dynamic>{'context_uri': uri};
      await player('PUT', 'play', body: body);
      return false;
    } on SpotifyException catch (e) {
      dlog('Web API play failed, opening Spotify: $e');
      await _actions.spotifyPlay(
          clientID: clientID, redirectUri: kSpotifyRedirectUri, uri: uri);
      return true;
    }
  }

  Future<void> queue(String uri) => player('POST', 'queue', query: <String, String>{'uri': uri});
  Future<void> next() => player('POST', 'next');
  Future<void> pause() => player('PUT', 'pause');
  Future<void> resume() => player('PUT', 'play');

  /// Player endpoints answer 204 on success and 404 when no device is active.
  Future<void> player(String method, String path,
      {Map<String, String>? query, Map<String, dynamic>? body}) async {
    final http.Request req = http.Request(method, Uri.https('api.spotify.com', '/v1/me/player/$path', query));
    req.headers['Authorization'] = 'Bearer ${await _userToken()}';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    final http.Response res = await http.Response.fromStream(await _http.send(req));
    if (res.statusCode == 404) {
      throw const SpotifyException(kSpotifyNoDevice);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw SpotifyException('Spotify (${res.statusCode}): ${res.body}');
    }
  }

  static Map<String, dynamic> _json(http.Response res) {
    try {
      final dynamic decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
    } on FormatException {
      return const <String, dynamic>{};
    }
  }

  static String _base64Url(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');
}
