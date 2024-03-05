/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2020-2023 Miðeind ehf. <mideind@mideind.is>
 * Original author: Sveinbjorn Thordarson
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

/// Voice selection route. Subroute of SettingsRoute.

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'package:embla_core/embla_core.dart' show AudioPlayer;

import './prefs.dart' show Prefs;
import './common.dart';
import './theme.dart';

/// Build a list view of available voices
Widget _buildVoiceList(BuildContext context) {
  const List<String> voices = kDebugMode ? kSpeechSynthesisDebugVoices : kSpeechSynthesisVoices;

  return ListView.builder(
    itemCount: voices.length,
    itemBuilder: (BuildContext context, int index) {
      return ListTile(
        title: Text(voices[index]),
        leading: IconButton(
            onPressed: null,
            icon: ImageIcon(
              img4theme('waveform', context),
              color: color4ctx(context),
            )),
        trailing: (voices[index] == Prefs().stringForKey("voice_id"))
            ? Icon(
                Icons.done,
                color: color4ctx(context),
              ) // Checkmark
            : null,
        onTap: () {
          Prefs().setStringForKey("voice_id", voices[index]);
          AudioPlayer().playSound("mynameis", Prefs().stringForKey('voice_id')!, null,
              Prefs().doubleForKey("voice_speed")!);
          Navigator.pop(context);
        },
      );
    },
  );
}

class VoiceSelectionRoute extends StatelessWidget {
  const VoiceSelectionRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: standardAppBar, body: _buildVoiceList(context));
  }
}
