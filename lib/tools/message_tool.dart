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

// draft_message: opens the messaging app with the text prefilled.
//
// Nothing is ever sent automatically: the user has to tap send. Contact lookup
// by name is out of scope, so a name without a number opens an empty
// recipient field.

import 'package:url_launcher/url_launcher.dart' show launchUrl;

import 'tool.dart' show Tool, ToolContext, ToolResult;
import 'tool_args.dart';

/// Injectable side effect: opens [uri] in the appropriate app.
typedef LaunchUri = Future<bool> Function(Uri uri);

Future<bool> defaultLaunchUri(Uri uri) => launchUrl(uri);

/// Builds the `sms:` URI that prefills the composer.
///
/// The two platforms disagree about the separator: iOS Messages expects
/// `sms:<number>&body=...` while Android's SMS handlers parse a proper query
/// string, `sms:<number>?body=...`. Both want the body percent-encoded with
/// `%20` rather than `+`, so the query is built by hand.
Uri buildSmsUri({String? phoneNumber, required String body, required bool isIOS}) {
  final String number = phoneNumber ?? '';
  final String separator = isIOS ? '&' : '?';
  return Uri.parse('sms:$number${separator}body=${Uri.encodeComponent(body)}');
}

/// Keeps digits and a leading plus, drops the spaces, dashes and parentheses
/// the model tends to copy from speech.
String? sanitizePhoneNumber(String? raw) {
  if (raw == null) {
    return null;
  }
  final bool international = raw.trimLeft().startsWith('+');
  final String digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) {
    return null;
  }
  return international ? '+$digits' : digits;
}

class DraftMessageTool extends Tool {
  final LaunchUri launchUri;
  final bool isIOS;

  DraftMessageTool({required this.isIOS, LaunchUri? launchUri})
      : launchUri = launchUri ?? defaultLaunchUri;

  @override
  String get name => 'draft_message';

  @override
  String get description =>
      'Opnar skilaboðaforrit tækisins með útfylltum texta. Skilaboðin eru aldrei '
      'send sjálfkrafa, notandinn þarf sjálfur að ýta á senda. Ekki er hægt að '
      'fletta upp símanúmeri eftir nafni: ef aðeins nafn viðtakanda er þekkt '
      'opnast skilaboðin án viðtakanda og notandinn velur hann sjálfur.';

  @override
  String? get activityLabel => 'Opna skilaboð…';

  @override
  Map<String, dynamic> get parameters => strictObjectSchema(<String, Map<String, dynamic>>{
        'recipient_name': optionalStringProperty('Nafn viðtakanda eins og notandinn sagði það, '
            'í nefnifalli. Skilaðu null ef ekkert nafn er nefnt.'),
        'phone_number': optionalStringProperty('Símanúmer viðtakanda ef notandinn segir það. '
            'Skilaðu null annars.'),
        'body': stringProperty('Texti skilaboðanna, umorðaður í fyrstu persónu frá sjónarhóli '
            'notandans („ég kem heim eftir hálftíma“, ekki „að ég komi heim eftir hálftíma“).'),
      });

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final String? body = optionalString(args['body']);
    if (body == null) {
      return ToolResult.failure('Vantar texta skilaboðanna (body).');
    }
    final String? name = optionalString(args['recipient_name']);
    final String? number = sanitizePhoneNumber(optionalString(args['phone_number']));

    final Uri uri = buildSmsUri(phoneNumber: number, body: body, isIOS: isIOS);
    final bool opened = await launchUri(uri);
    if (!opened) {
      return ToolResult.failure('Ekki tókst að opna skilaboðaforritið.');
    }

    final String summary;
    if (number != null) {
      summary = 'Skilaboð til $number opnuð í skilaboðaforriti';
    } else if (name != null) {
      summary = 'Skilaboð opnuð í skilaboðaforriti, en ég hef ekki símanúmer '
          '$name svo notandinn þarf að velja viðtakanda sjálfur';
    } else {
      summary = 'Skilaboð opnuð í skilaboðaforriti';
    }
    return ToolResult.success(<String, dynamic>{'summary': summary}, endsTurn: true);
  }
}
