/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2020-2022 Miðeind ehf. <mideind@mideind.is>
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
// import './query.dart' show QueryService;
import './common.dart'
    show dlog, kSpeechSynthesisVoices, kSpeechSynthesisDebugVoices /*, kDefaultVoice*/;
import './theme.dart';
import './audio.dart';

const String kVoicesLoadingMsg = 'Raddir eru að hlaðast…';

List<String> voices = kSpeechSynthesisVoices;

// Fetch list of voice IDs (strings) from server
Future<List<String>> fetchVoiceList() async {
  if (kReleaseMode) {
    voices = kSpeechSynthesisVoices;
  } else {
    voices = kSpeechSynthesisDebugVoices;
  }

  return voices;

  // This is disabled for now.
  // try {
  //   Map<String, dynamic> res = await QueryService.requestSupportedVoices();
  //   List<dynamic> voiceList = kSpeechSynthesisVoices;
  //   String defaultVoice = kDefaultVoice;

  //   if (res != null && res.containsKey("valid") == true && res["valid"] == true) {
  //     // We have a valid response from the server

  //     if (res.containsKey("default") == true && res["default"] != null) {
  //       defaultVoice = res["default"];
  //     }

  //     // Debug mode
  //     if (res.containsKey("supported") == true) {
  //       voiceList = res["supported"] as List<dynamic>;
  //     }
  //   }
  //   // Make sure current voice is sane
  //   if (voiceList.contains(Prefs().stringForKey("voice_id")) == false) {
  //     Prefs().setStringForKey("voice_id", defaultVoice);
  //   }

  //   // Store voices list once fetched
  //   voices = voiceList;
  // } catch (e) {
  //   dlog("Error fetching voice list: $e");
  //   voices = kSpeechSynthesisVoices;
  // }

  // return voices;
}

Widget _buildVoiceList(BuildContext context, List voices) {
  return ListView.builder(
    itemCount: voices.length,
    itemBuilder: (BuildContext context, int index) {
      return ListTile(
        title: Text(voices[index]),
        leading: IconButton(
            onPressed: null,
            icon: ImageIcon(
              AssetImage('assets/images/waveform.png'),
              color: color4ctx(context),
            )),
        trailing: voices[index] == Prefs().stringForKey("voice_id")
            ? Icon(
                Icons.done,
                color: color4ctx(context),
              ) // Checkmark
            : null,
        onTap: () {
          Prefs().setStringForKey("voice_id", voices[index]);
          AudioPlayer().playSound("mynameis");
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
        if (snapshot.hasData == false) {
          // No data yet
          return Center(
            child: CircularProgressIndicator(
              semanticsLabel: kVoicesLoadingMsg,
            ),
          );
        } else {
          // We have received voice list from server
          dlog("Building voice list from ${snapshot.data}");
          return _buildVoiceList(context, snapshot.data!);
        }
      });
}

class VoiceSelectionRoute extends StatelessWidget {
  const VoiceSelectionRoute({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: standardAppBar, body: _genVoiceList());
  }
}
