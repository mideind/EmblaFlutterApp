/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2020 Miðeind ehf. <mideind@mideind.is>
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

// Animations

import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import './common.dart';

const String frameFileName = 'assets/images/anim/logo/anim_';
const String frameFileSuffix = '.png';

final List animationFrames = [];

Future<ui.Image> _loadImageAsset(String asset) async {
  ByteData data = await rootBundle.load(asset);
  ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  ui.FrameInfo fi = await codec.getNextFrame();
  return fi.image;
}

Future<void> preloadAnimationFrames() async {
  dlog('Preloading animation frames');
  NumberFormat formatter = new NumberFormat('00000');
  for (int i = 0; i < 100; i++) {
    String fn = "$frameFileName${formatter.format(i)}$frameFileSuffix";
    animationFrames.add(await _loadImageAsset(fn));
  }
  dlog("Preloaded ${animationFrames.length} animation frames");
}