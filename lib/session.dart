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

// Session (main) view

import 'dart:math';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:google_speech/generated/google/cloud/speech/v1/cloud_speech.pb.dart';
import 'package:google_speech/google_speech.dart';
import 'package:sound_stream/sound_stream.dart';
import 'package:audioplayers/audioplayers.dart' show AudioPlayer;

import './query.dart' show QueryService;
import './util.dart';
import './common.dart';

final audioPlayer = AudioPlayer();

class SessionWidget extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _SessionWidgetState();
}

class _SessionWidgetState extends State<SessionWidget> with TickerProviderStateMixin {
  final RecorderStream _recorder = RecorderStream();

  double buttonSize = 200;
  bool recognizing = false;
  bool recognizeFinished = false;
  bool awaitingAnswer = false;
  String text = '';
  ui.Image image;

  @override
  void initState() {
    super.initState();
    _recorder.initialize();
  }

  void didChangeDependencies() async {
    super.didChangeDependencies();
    var img = await loadImageAsset("assets/images/logo.png");
    setState(() {
      this.image = img;
      dlog("Loaded image " + image.toString());
    });
  }

  Future<ui.Image> loadImageAsset(String asset) async {
    ByteData data = await rootBundle.load(asset);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    ui.FrameInfo fi = await codec.getNextFrame();
    return fi.image;
  }

  void streamingRecognize() async {
    audioPlayer.stop();
    await _recorder.start();

    setState(() {
      recognizing = true;
      text = '';
      buttonSize = 300;
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
    if (awaitingAnswer) {
      return;
    }

    setState(() {
      awaitingAnswer = true;
      buttonSize = 200;
    });
    String res = finalResult.alternatives.first.transcript;
    QueryService.sendQuery([res], (Map resp) async {
      if (resp["valid"] == true) {
        dlog("Received valid response to query");
        dlog("Playing audio" + resp["audio"]);
        audioPlayer.stop();
        await audioPlayer.play(resp["audio"]);
        setState(() {
          text = resp["answer"];
        });
      } else {
        setState(() {
          text = 'Það veit ég ekki.';
        });
      }
      setState(() {
        awaitingAnswer = false;
      });
    });
  }

  RecognitionConfig _getConfig() {
    return RecognitionConfig(
        encoding: AudioEncoding.LINEAR16,
        model: RecognitionModel.command_and_search,
        enableAutomaticPunctuation: true,
        sampleRateHertz: 16000,
        languageCode: 'is-IS');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            if (recognizeFinished)
              _RecognizedSpeechWidget(
                text: text,
              ),
            RaisedButton(
              onPressed: recognizing ? stopRecording : streamingRecognize,
              child: recognizing ? Text('Hætta') : Text('Hlusta'),
            ),
            AnimatedSize(
                curve: Curves.elasticInOut,
                duration: Duration(seconds: 2),
                vsync: this,
                alignment: Alignment.center,
                child: new SizedBox(
                  width: buttonSize,
                  height: buttonSize,
                  child: CustomPaint(painter: SessionButtonPainter(image)),
                )),
            // AnimatedContainer(
            //     duration: Duration(seconds: 2),
            //     child: SizedBox(
            //         width: buttonSize,
            //         height: buttonSize,
            //         child: CustomPaint(painter: SessionButtonPainter(image))))
          ],
        ),
      ),
    );
  }
}

class SessionButtonPainter extends CustomPainter {
  ui.Image image;

  // Outermost to innermost
  final circleColor1 = HexColor.fromHex("#F9F0F0");
  final circleColor2 = HexColor.fromHex("#F9E2E1");
  final circleColor3 = HexColor.fromHex("#F9DCDB");

  SessionButtonPainter(this.image);

  @override
  void paint(Canvas canvas, Size size) async {
    final radius = min(size.width, size.height) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    // First circle
    var paint = Paint()..color = circleColor1;
    canvas.drawCircle(center, radius, paint);
    // Second circle
    paint = Paint()..color = circleColor2;
    canvas.drawCircle(center, radius / 1.25, paint);
    // Third circle
    paint = Paint()..color = circleColor3;
    canvas.drawCircle(center, radius / 1.75, paint);
    // Draw logo if image is already asynchronously loaded
    if (image != null) {
      // Source image rect
      double imgWidth = image.width.toDouble();
      double imgHeight = image.height.toDouble();
      Rect src = const Offset(0, 0) & Size(imgWidth, imgHeight);
      // Destination rect centered in canvas
      double w = size.width.toDouble() / 2.5;
      double h = size.height.toDouble() / 2.5;
      Rect dst =
          Offset((size.width.toDouble() / 2) - (w / 2), (size.height.toDouble() / 2) - (h / 2)) &
              Size(w, h);
      canvas.drawImageRect(image, src, dst, Paint());
    }
  }

  @override
  bool shouldRepaint(SessionButtonPainter oldDelegate) {
    return false;
  }
}

class _RecognizedSpeechWidget extends StatelessWidget {
  final String text;

  const _RecognizedSpeechWidget({Key key, this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: <Widget>[
          Text(
            text != null ? text : '',
            style: Theme.of(context).textTheme.bodyText1,
          ),
        ],
      ),
    );
  }
}
