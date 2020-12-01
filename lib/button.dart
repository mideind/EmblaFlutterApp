import 'dart:math';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audio_cache.dart';
import 'package:audioplayers/audioplayers.dart';

import './util.dart';
import './common.dart';

final audioPlayer = AudioPlayer();
final audioCache = new AudioCache(fixedPlayer: audioPlayer);

class SessionWidget extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _SessionWidgetState();
}

class _SessionWidgetState extends State<SessionWidget> with TickerProviderStateMixin {
  ui.Image image;
  bool expanded = false;

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
    String soundFile = expanded ? "rec_cancel.wav" : 'rec_begin.wav';

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            GestureDetector(
                onTap: () {
                  setState(() {
                    audioCache.play('audio/' + soundFile);
                    expanded = !expanded;
                  });
                },
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
    return true;
  }
}
