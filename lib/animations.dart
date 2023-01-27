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

// Animations

import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import './common.dart';

const String kFrameFilePath = 'assets/images/anim/logo/';
const String kFrameFilePrefix = 'anim_';
const String kFrameFileSuffix = '.png';
const int kNumAnimationFrames = 100;

final List<ui.Image> animationFrames = [];

/// Load a PNG image into memory from Flutter assets bundle
Future<ui.Image> _loadImageAsset(String asset) async {
  ByteData data = await rootBundle.load(asset);
  ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  ui.FrameInfo fi = await codec.getNextFrame();
  return fi.image;
}

/// Preload all logo animation frames
Future<void> preloadAnimationFrames() async {
  for (int i = 0; i < kNumAnimationFrames; i++) {
    String padnum = i.toString().padLeft(5, '0');
    // Light mode anim frame
    String fnl = "${kFrameFilePath}light/$kFrameFilePrefix$padnum$kFrameFileSuffix";
    animationFrames.add(await _loadImageAsset(fnl));
  }
  dlog("Preloaded ${animationFrames.length} animation frames");
}
