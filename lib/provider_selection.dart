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

// Generic single-choice selection route for a string value in Prefs.
// Subroute of SettingsRoute, used for e.g. ASR and TTS provider selection.

import 'package:flutter/material.dart';

import './prefs.dart' show Prefs;
import './theme.dart';

/// Look up the human-readable label for a value in an option list.
/// Falls back to the value itself if it isn't in the list.
String labelForValue(List<List<String>> options, String? value) {
  for (final List<String> option in options) {
    if (option[0] == value) {
      return option[1];
    }
  }
  return value ?? '';
}

/// Radio-style selection route bound to a string pref.
/// [options] is a list of [value, label] pairs.
class ProviderSelectionRoute extends StatefulWidget {
  final String title;
  final String prefKey;
  final List<List<String>> options;
  final void Function(String value)? onSelected;

  const ProviderSelectionRoute({
    super.key,
    required this.title,
    required this.prefKey,
    required this.options,
    this.onSelected,
  });

  @override
  ProviderSelectionRouteState createState() => ProviderSelectionRouteState();
}

class ProviderSelectionRouteState extends State<ProviderSelectionRoute> {
  void _select(String value) {
    setState(() {
      Prefs().setStringForKey(widget.prefKey, value);
    });
    widget.onSelected?.call(value);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final String? currentValue = Prefs().stringForKey(widget.prefKey);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: menuTextStyle),
        bottomOpacity: 0.0,
        elevation: 0.0,
        toolbarOpacity: 1.0,
      ),
      body: ListView.builder(
        itemCount: widget.options.length,
        itemBuilder: (BuildContext context, int index) {
          final List<String> option = widget.options[index];
          return ListTile(
            title: Text(option[1]),
            leading: IconButton(
                onPressed: null,
                icon: ImageIcon(
                  img4theme('waveform', context),
                  color: color4ctx(context),
                )),
            trailing: (option[0] == currentValue)
                ? Icon(
                    Icons.done,
                    color: color4ctx(context),
                  ) // Checkmark
                : null,
            onTap: () {
              _select(option[0]);
            },
          );
        },
      ),
    );
  }
}
