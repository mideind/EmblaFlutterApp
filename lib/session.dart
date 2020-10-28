/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2020 Miðeind ehf.
 * Author: Sveinbjorn Thordarson
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:google_speech/generated/google/cloud/speech/v1/cloud_speech.pb.dart';
import 'package:google_speech/google_speech.dart';
import 'package:sound_stream/sound_stream.dart';
import 'package:audioplayers/audioplayers.dart' show AudioPlayer;

import './query.dart' show QueryService;
import './common.dart';

final audioPlayer = AudioPlayer();

class AudioRecognize extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _AudioRecognizeState();
}

class _AudioRecognizeState extends State<AudioRecognize> {
  final RecorderStream _recorder = RecorderStream();

  bool recognizing = false;
  bool recognizeFinished = false;
  String text = '';

  @override
  void initState() {
    super.initState();

    _recorder.initialize();
  }

  void streamingRecognize() async {
    await _recorder.start();

    setState(() {
      recognizing = true;
    });
    final serviceAccount = ServiceAccount.fromString(
        '${(await rootBundle.loadString('assets/test_service_account.json'))}');
    final speechToText = SpeechToText.viaServiceAccount(serviceAccount);
    final config = _getConfig();

    final responseStream = speechToText.streamingRecognize(
        StreamingRecognitionConfig(config: config, interimResults: true, singleUtterance: false),
        _recorder.audioStream);

    responseStream.listen((data) {
      setState(() {
        text = data.results.map((e) => e.alternatives.first.transcript).join('\n');
        dlog("RESULTS--------------");
        dlog(data.results.toString());
        recognizeFinished = true;
        if (data.results.length < 1) {
          return;
        }
        var first = data.results[0];
        if (first.isFinal) {
          dlog("Final result received, stopping recording");
          stopRecording();
          handleFinal(first);
        }
      });
    }, onDone: () {
      dlog("Stream done");
      stopRecording();
    });
  }

  void stopRecording() async {
    await _recorder.stop();
    setState(() {
      recognizing = false;
    });
  }

  Future<void> handleFinal(var finalResult) async {
    print("HANDLING RESPONSE");
    String res = finalResult.alternatives.first.transcript;
    QueryService.sendQuery([res], (Map resp) async {
      print("Playing audio");
      print(resp["audio"]);
      int result = await audioPlayer.play(resp["audio"]);
      print("Audio player result: $result");
      text = resp["answer"];
    });
  }

  RecognitionConfig _getConfig() => RecognitionConfig(
      encoding: AudioEncoding.LINEAR16,
      model: RecognitionModel.command_and_search,
      enableAutomaticPunctuation: true,
      sampleRateHertz: 16000,
      languageCode: 'is-IS');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            if (recognizeFinished)
              _RecognizeContent(
                text: text,
              ),
            RaisedButton(
              onPressed: recognizing ? stopRecording : streamingRecognize,
              child: recognizing ? Text('Hætta') : Text('Hlusta'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecognizeContent extends StatelessWidget {
  final String text;

  const _RecognizeContent({Key key, this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: <Widget>[
          Text(
            text,
            style: Theme.of(context).textTheme.bodyText1,
          ),
        ],
      ),
    );
  }
}
