import 'dart:math';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audio_cache.dart';
import 'package:audioplayers/audioplayers.dart';

import './util.dart';
import './common.dart';

final audioPlayer = AudioPlayer();
final audioCache = new AudioCache(fixedPlayer: audioPlayer);

const AWV_DEFAULT_NUM_BARS = 15;
const AWV_DEFAULT_BAR_SPACING = 4.0;
const AWV_DEFAULT_SAMPLE_LEVEL = 0.05; // A hard lower limit above 0 looks better
const AWV_DEFAULT_VARIATION = 0.025; // Variation range for bars when reset
const AWV_MIN_SAMPLE_LEVEL = 0.025; // Hard limit on lowest level

final List audioSamples = <double>[
  0.025,
  0.5,
  0.3,
  0.2,
  1.0,
  0.7,
  0.025,
  0.5,
  0.3,
  0.2,
  1.0,
  0.7,
  0.025,
  0.5,
  0.3
];

class SessionWidget extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _SessionWidgetState();
}

class _SessionWidgetState extends State<SessionWidget> with TickerProviderStateMixin {
  ui.Image image;
  bool expanded = false;
  Timer timer;

  void didChangeDependencies() async {
    super.didChangeDependencies();
    var img = await loadImageAsset("assets/images/logo.png");
    setState(() {
      this.image = img;
      //dlog("Loaded image " + image.toString());
    });
  }

  Future<ui.Image> loadImageAsset(String asset) async {
    ByteData data = await rootBundle.load(asset);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    ui.FrameInfo fi = await codec.getNextFrame();
    return fi.image;
  }

  @override
  Widget build(BuildContext context) {
    double prop = expanded ? 0.65 : 0.5;
    double buttonSize = MediaQuery.of(context).size.width * prop;

    void updateAnim() {
      setState(() {
        audioSamples.removeAt(0);
        audioSamples.add(Random().nextDouble());
      });
    }

    void stop() {
      setState(() {
        audioPlayer.stop();
        audioCache.play('audio/rec_cancel.wav');
        timer.cancel();
      });
    }

    void start() {
      setState(() {
        audioPlayer.stop();
        audioCache.play('audio/rec_begin.wav');
        timer = new Timer.periodic(Duration(milliseconds: (1000 ~/ 60)), (Timer t) => updateAnim());
      });
    }

    void toggle() {
      expanded = !expanded;
      if (expanded) {
        start();
      } else {
        stop();
      }
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            GestureDetector(
                onTap: toggle,
                child: AnimatedSize(
                    curve: Curves.linear,
                    duration: Duration(milliseconds: 10),
                    vsync: this,
                    alignment: Alignment.center,
                    child: new SizedBox(
                      width: buttonSize,
                      height: buttonSize,
                      child: CustomPaint(painter: SessionButtonPainter(image)),
                    ))),
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
    if (false && image != null) {
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
    // Draw audio signal bars
    double margin = AWV_DEFAULT_BAR_SPACING;
    double totalMarginWidth = AWV_DEFAULT_NUM_BARS * margin;

    double barWidth = (size.width - totalMarginWidth) / AWV_DEFAULT_NUM_BARS;
    double barHeight = size.height / 2;
    double centerY = size.height / 2;

    for (int i = 0; i < audioSamples.length; i++) {
      double level = audioSamples[i];
      paint = Paint()..color = Colors.red;

      // Draw top bar
      Rect topRect = new Rect.fromLTWH(
          i * (barWidth + margin) + (margin / 2), // x
          barHeight - (level * barHeight), // y
          barWidth, // width
          level * barHeight); // height
      canvas.drawRect(topRect, paint);
      // Draw circle at end of bar
      canvas.drawCircle(
          Offset(i * (barWidth + margin) + barWidth / 2 + (margin / 2),
              barHeight - (level * barHeight)),
          barWidth / 2,
          paint);

      // Draw bottom bar
      Rect bottomRect = new Rect.fromLTWH(
          i * (barWidth + margin) + (margin / 2), // x
          centerY, // y
          barWidth, // width
          level * barHeight); // height
      canvas.drawRect(bottomRect, paint);
      // Draw circle at end of bar
      canvas.drawCircle(
          Offset(
              i * (barWidth + margin) + barWidth / 2 + (margin / 2), centerY + (level * barHeight)),
          barWidth / 2,
          paint);
    }
  }

  @override
  bool shouldRepaint(SessionButtonPainter oldDelegate) {
    return true;
  }
}
