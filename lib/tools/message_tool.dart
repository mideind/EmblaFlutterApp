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

// draft_message: sends a text message.
//
// The app cannot send SMS itself. When a Shortcut drives the turn, the
// recipient and body go back to it as `action: send_message` and its Send
// Message action does the sending. Otherwise the messaging app opens with the
// text prefilled and the user taps send.

import 'package:url_launcher/url_launcher.dart' show launchUrl;

import 'tool.dart' show ShortcutHandoff, Tool, ToolContext, ToolResult, noShortcutHandoff;
import 'contact_match.dart';
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

/// Injectable side effect: the device address book. Returns an empty list when
/// permission is refused, so a missing permission degrades to "no recipient
/// found" rather than an error.
typedef LookupContacts = Future<List<ContactCandidate>> Function();

class DraftMessageTool extends Tool {
  final LaunchUri launchUri;
  final bool isIOS;

  /// Null when contact lookup is unavailable on this platform or build.
  final LookupContacts? lookupContacts;
  final ShortcutHandoff handOff;

  DraftMessageTool(
      {required this.isIOS, LaunchUri? launchUri, this.lookupContacts, ShortcutHandoff? handOff})
      : launchUri = launchUri ?? defaultLaunchUri,
        handOff = handOff ?? noShortcutHandoff;

  @override
  String get name => 'draft_message';

  @override
  String get description =>
      'Sendir SMS/iMessage á viðtakanda. Viðtakandi er fundinn í tengiliðum eftir '
      'nafni eða með símanúmeri. Ef enginn viðtakandi er nefndur opnast skilaboðin '
      'án viðtakanda og notandinn velur hann sjálfur.';

  @override
  String? get activityLabel => 'Sendi skilaboð…';

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
    String? number = sanitizePhoneNumber(optionalString(args['phone_number']));

    // A spoken name arrives declined ("Kára Steini") while the address book
    // stores the nominative ("Kári Steinn"), so resolve it rather than handing
    // the composer a name it cannot use as a recipient.
    String? resolvedName;
    if (number == null && name != null && lookupContacts != null) {
      final ContactMatch match = matchContact(name, await lookupContacts!());
      switch (match) {
        case ContactResolved(:final contact):
          resolvedName = contact.displayName;
          number = sanitizePhoneNumber(
              contact.phoneNumbers.isEmpty ? null : contact.phoneNumbers.first);
        case ContactAmbiguous(:final candidates):
          // Sending to the wrong person is worse than one more question, so
          // stop here without opening the composer.
          return ToolResult.success(<String, dynamic>{
            'ambiguous': true,
            'candidates': candidates.map((ContactCandidate c) => c.displayName).toList(),
            'summary': 'Fleiri en einn tengiliður passar við „$name“. Spurðu notandann '
                'hvern hann meinar og nefndu valkostina.',
          });
        case ContactNotFound():
          break;
      }
    }

    // A shortcut-driven turn: the shortcut sends, the app only confirms.
    final String? recipient = resolvedName ?? name;
    if ((recipient != null || number != null) &&
        handOff(<String, dynamic>{
          'action': 'send_message',
          'recipient_name': recipient,
          if (number != null) 'phone_number': number,
          'body': body,
        })) {
      final String who = recipient ?? number!;
      return ToolResult.success(<String, dynamic>{'summary': 'Skilaboð til $who afhent flýtileið til sendingar'},
          endsTurn: true, speech: 'Ég sendi skilaboð til $who.');
    }

    final Uri uri = buildSmsUri(phoneNumber: number, body: body, isIOS: isIOS);
    final bool opened = await launchUri(uri);
    if (!opened) {
      return ToolResult.failure('Ekki tókst að opna skilaboðaforritið.');
    }

    final String summary;
    final String speech;
    if (number != null) {
      summary = resolvedName == null
          ? 'Skilaboð til $number opnuð í skilaboðaforriti'
          : 'Skilaboð til $resolvedName ($number) opnuð í skilaboðaforriti';
      speech = resolvedName == null
          ? 'Ég opnaði skilaboðin, þú getur sent þau.'
          : 'Ég opnaði skilaboð til $resolvedName, þú getur sent þau.';
    } else if (name != null) {
      summary = 'Skilaboð opnuð í skilaboðaforriti, en ég hef ekki símanúmer '
          '$name svo notandinn þarf að velja viðtakanda sjálfur';
      speech = 'Ég opnaði skilaboðin en fann ekki símanúmer hjá $name, '
          'þú þarft að velja viðtakanda.';
    } else {
      summary = 'Skilaboð opnuð í skilaboðaforriti';
      speech = 'Ég opnaði skilaboðin.';
    }
    return ToolResult.success(
        <String, dynamic>{'summary': summary}, endsTurn: true, speech: speech);
  }
}
