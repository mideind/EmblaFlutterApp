/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2026 Miðeind ehf. <mideind@mideind.is>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

// Starts turn-by-turn navigation in the device's map app.

import '../prefs.dart' show Prefs;
import 'message_tool.dart' show LaunchUri, defaultLaunchUri;
import 'tool.dart';
import 'tool_args.dart';

/// Apple Maps cannot be told to *start* navigation from a URL: `dirflg=d`
/// preselects driving but the user still has to tap "Akstur". Google Maps
/// honours `dir_action=navigate`, and its https form degrades to the browser
/// when the app is absent, so it is offered behind a setting.
Uri buildDirectionsUri(String destination, {required bool useGoogleMaps}) {
  final String d = Uri.encodeComponent(destination);
  return Uri.parse(useGoogleMaps
      ? 'https://www.google.com/maps/dir/?api=1&destination=$d'
          '&travelmode=driving&dir_action=navigate'
      : 'maps://?daddr=$d&dirflg=d');
}

class GetDirectionsTool extends Tool {
  final LaunchUri launchUri;

  /// Read at call time so the setting can change between turns.
  final bool Function() preferGoogleMaps;

  GetDirectionsTool({LaunchUri? launchUri, bool Function()? preferGoogleMaps})
      : launchUri = launchUri ?? defaultLaunchUri,
        preferGoogleMaps =
            preferGoogleMaps ?? (() => Prefs().boolForKey('use_google_maps'));

  @override
  String get name => 'get_directions';

  @override
  String get description =>
      'Ræsir leiðsögn í kortaforriti að áfangastað. Notaðu þetta þegar notandinn '
      'vill komast eitthvað, t.d. „vísaðu mér á Hörpu“ eða „hvernig kemst ég í Kringluna“.';

  @override
  String? get activityLabel => 'Opna leiðsögn…';

  @override
  Map<String, dynamic> get parameters => strictObjectSchema(<String, Map<String, dynamic>>{
        'destination': stringProperty(
            'Áfangastaðurinn eins og notandinn sagði hann, í nefnifalli, '
            't.d. „Harpa“ eða „Laugavegur 22“.'),
      });

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final String? destination = optionalString(args['destination']);
    if (destination == null) {
      return ToolResult.failure('Vantar áfangastað (destination).');
    }
    final Uri uri = buildDirectionsUri(destination, useGoogleMaps: preferGoogleMaps());
    final bool opened = await launchUri(uri);
    if (!opened) {
      return ToolResult.failure('Ekki tókst að opna kortaforritið.');
    }
    return ToolResult.success(
      <String, dynamic>{'summary': 'Leiðsögn að „$destination“ opnuð í kortaforriti'},
      endsTurn: true,
      speech: 'Ég opna leiðsögn að $destination.',
    );
  }
}
