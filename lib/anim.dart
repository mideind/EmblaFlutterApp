/*

*/

import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

List animationFrames = [];
const String frameFn = 'assets/anim/logo/EMBLA_256px_';
const String frameSuffix = '.png';

Future<ui.Image> loadImageAsset(String asset) async {
  ByteData data = await rootBundle.load(asset);
  ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  ui.FrameInfo fi = await codec.getNextFrame();
  return fi.image;
}

void loadFrames() async {
  NumberFormat formatter = new NumberFormat("00000");
  for (int i = 0; i < 100; i++) {
    String fn = "${frameFn}${formatter.format(i)}${frameSuffix}";
    animationFrames.add(await loadImageAsset(fn));
  }
  //print(animationFrames);
}
