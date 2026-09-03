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

// Reads the device address book, for resolving spoken recipient names.
// Kept apart from contact_match.dart so the matching logic stays unit-testable
// without the plugin.

import 'package:flutter_contacts/flutter_contacts.dart' as fc;

import '../common.dart' show dlog;
import 'contact_match.dart';

/// Contacts with at least a name, for name matching.
///
/// Returns an empty list when permission is refused or the plugin is
/// unavailable: no recipient found is a better outcome than a failed turn,
/// since the composer still opens for the user to pick someone.
Future<List<ContactCandidate>> deviceContacts() async {
  try {
    if (await fc.FlutterContacts.requestPermission(readonly: true) == false) {
      dlog('Contacts: permission refused');
      return const <ContactCandidate>[];
    }
    final List<fc.Contact> contacts =
        await fc.FlutterContacts.getContacts(withProperties: true);
    return contacts
        .where((fc.Contact c) => c.displayName.trim().isNotEmpty)
        .map((fc.Contact c) => ContactCandidate(
              displayName: c.displayName,
              phoneNumbers:
                  c.phones.map((fc.Phone p) => p.number).where((String n) => n.isNotEmpty).toList(),
            ))
        .toList(growable: false);
  } catch (e) {
    dlog('Contacts lookup failed: $e');
    return const <ContactCandidate>[];
  }
}
