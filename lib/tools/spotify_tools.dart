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

// play_music, queue_music and control_music, on top of SpotifyClient.

import '../spotify_client.dart' show SpotifyClient, SpotifyException;
import 'tool.dart' show Tool, ToolContext, ToolResult;
import 'tool_args.dart';

String _describe(String title, String? artist) => artist == null ? '„$title“' : '„$title“ með $artist';

class PlayMusicTool extends Tool {
  final SpotifyClient spotify;
  PlayMusicTool(this.spotify);

  @override
  String get name => 'play_music';

  @override
  String get description =>
      'Spilar lag eða lagalista á Spotify. Notaðu kind=track fyrir lag (title er heiti '
      'lagsins, artist flytjandinn ef hann er nefndur) og kind=playlist fyrir lagalista '
      '(title er heiti listans).';

  @override
  String? get activityLabel => 'Leita á Spotify…';

  @override
  Map<String, dynamic> get parameters => strictObjectSchema(<String, Map<String, dynamic>>{
        'kind': enumProperty(const <String>['track', 'playlist'], 'Lag eða lagalisti.'),
        'title': stringProperty('Heiti lagsins eða lagalistans.'),
        'artist': optionalStringProperty('Flytjandi lagsins ef hann er nefndur. Skilaðu null annars.'),
      });

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final String? title = optionalString(args['title']);
    if (title == null) {
      return ToolResult.failure('Vantar heiti (title).');
    }
    final String? artist = optionalString(args['artist']);
    final bool playlist = args['kind'] == 'playlist';
    try {
      final String uri = playlist
          ? await spotify.playlistUri(title)
          : await spotify.searchTrackUri(title: title, artist: artist);
      final bool openedApp = await spotify.play(uri);
      final String what = playlist ? 'lagalistann „$title“' : _describe(title, artist);
      return ToolResult.success(<String, dynamic>{'summary': 'Spila $what á Spotify', 'uri': uri},
          // The Spotify app is now in front; nothing more to say from here.
          endsTurn: openedApp,
          speech: 'Spila $what.');
    } on SpotifyException catch (e) {
      return ToolResult.failure(e.message);
    }
  }
}

class QueueMusicTool extends Tool {
  final SpotifyClient spotify;
  QueueMusicTool(this.spotify);

  @override
  String get name => 'queue_music';

  @override
  String get description => 'Setur lag í biðröðina á Spotify, á eftir því sem er í spilun.';

  @override
  String? get activityLabel => 'Leita á Spotify…';

  @override
  Map<String, dynamic> get parameters => strictObjectSchema(<String, Map<String, dynamic>>{
        'title': stringProperty('Heiti lagsins.'),
        'artist': optionalStringProperty('Flytjandi lagsins ef hann er nefndur. Skilaðu null annars.'),
      });

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final String? title = optionalString(args['title']);
    if (title == null) {
      return ToolResult.failure('Vantar heiti lagsins (title).');
    }
    final String? artist = optionalString(args['artist']);
    try {
      final String uri = await spotify.searchTrackUri(title: title, artist: artist);
      await spotify.queue(uri);
      return ToolResult.success(
          <String, dynamic>{'summary': 'Setti ${_describe(title, artist)} í biðröðina á Spotify'});
    } on SpotifyException catch (e) {
      return ToolResult.failure(e.message);
    }
  }
}

class ControlMusicTool extends Tool {
  final SpotifyClient spotify;
  ControlMusicTool(this.spotify);

  @override
  String get name => 'control_music';

  @override
  String get description =>
      'Stýrir spilun á Spotify: next hoppar í næsta lag, pause gerir hlé, resume heldur áfram.';

  @override
  String? get activityLabel => 'Stýri Spotify…';

  @override
  Map<String, dynamic> get parameters => strictObjectSchema(<String, Map<String, dynamic>>{
        'command': enumProperty(const <String>['next', 'pause', 'resume'], 'Aðgerðin.'),
      });

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final String? command = optionalString(args['command']);
    try {
      switch (command) {
        case 'next':
          await spotify.next();
          return ToolResult.success(const <String, dynamic>{'summary': 'Næsta lag'});
        case 'pause':
          await spotify.pause();
          return ToolResult.success(const <String, dynamic>{'summary': 'Hlé á spilun'});
        case 'resume':
          await spotify.resume();
          return ToolResult.success(const <String, dynamic>{'summary': 'Spilun heldur áfram'});
        default:
          return ToolResult.failure('Óþekkt skipun (command): $command');
      }
    } on SpotifyException catch (e) {
      return ToolResult.failure(e.message);
    }
  }
}
