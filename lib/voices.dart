/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2021 Miðeind ehf. <mideind@mideind.is>
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

// Voice selection route

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;

import './prefs.dart' show Prefs;
import './query.dart' show QueryService;
import './common.dart' show dlog;
import './theme.dart';

// Fallback voices and default voice if offline
// and unable to query server for voices list
const List _fallbackVoices = ["Dora", "Karl"];
const String _fallbackDefaultVoice = "Dora";

List voices = null;

Future<List> fetchVoiceList() async {
  if (voices != null) {
    return voices;
  }

  Map res = await QueryService.requestSupportedVoices();
  List voiceList = _fallbackVoices;
  String defaultVoice = _fallbackDefaultVoice;

  if (res != null && res.containsKey("valid") == true && res["valid"] == true) {
    // We have a valid response from the server

    if (res.containsKey("default") == true && res["default"] != null) {
      defaultVoice = res["default"];
    }

    // Release mode
    if (kReleaseMode == true && res.containsKey("recommended") == true) {
      voiceList = res["recommended"];
    }

    // Debug mode
    if (kReleaseMode == false && res.containsKey("supported") == true) {
      voiceList = res["supported"];
    }
  }
  // Make sure current voice is sane
  if (voiceList.contains(Prefs().stringForKey("voice_id")) == false) {
    Prefs().setStringForKey("voice_id", defaultVoice);
  }

  // Store voices list once fetched
  voices = voiceList;

  return voiceList;
}

Widget _buildVoiceList(BuildContext context, List voices) {
  return ListView.builder(
    itemCount: voices.length,
    itemBuilder: (BuildContext context, int index) {
      return ListTile(
        title: Text(voices[index]),
        leading: IconButton(
          icon: ImageIcon(AssetImage('assets/images/waveform.png'),
              color: Theme.of(context).primaryColorDark),
        ),
        trailing: voices[index] == Prefs().stringForKey("voice_id")
            ? Icon(
                Icons.done,
                color: Theme.of(context).primaryColorDark,
              )
            : null,
        onTap: () {
          Prefs().setStringForKey("voice_id", voices[index]);
          Navigator.pop(context);
        },
      );
    },
  );
}

FutureBuilder<List> _genVoiceList() {
  return FutureBuilder<List>(
      future: fetchVoiceList(),
      builder: (context, AsyncSnapshot<List> snapshot) {
        dlog(snapshot.toString());
        if (snapshot.hasData == false) {
          // No data yet
          return Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Raddir eru að hlaðast...',
            ),
          );
        } else {
          // We have received voice list from server
          dlog("Building voice list from ${snapshot.data}");
          return _buildVoiceList(context, snapshot.data);
        }
      });
}

class VoiceSelectionRoute extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: standardAppBar, body: _genVoiceList());
  }
}
