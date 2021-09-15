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

// Configure app theme: colors, fonts and other styling

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import './util.dart';

// Text, icons, accents
final Color mainColor = HexColor.fromHex('#e83939');
// Background
final Color bgColor = HexColor.fromHex('#f9f9f9');

// Session button circle colors, outermost to innermost
final Color circleColor1 = HexColor.fromHex('#f9f0f0');
final Color circleColor2 = HexColor.fromHex('#f9e2e1');
final Color circleColor3 = HexColor.fromHex('#f9dcdb');

const Brightness defaultBrightness = Brightness.light;

const String defaultFontFamily = 'Lato';
const double defaultFontSize = 18.0;
const double sessionFontSize = 24.0;

final TextStyle defaultTextStyle = TextStyle(color: mainColor, fontSize: defaultFontSize);
final TextStyle sessionTextStyle =
    TextStyle(color: mainColor, fontSize: sessionFontSize, fontStyle: FontStyle.italic);
final TextStyle menuTextStyle = TextStyle(color: Colors.black, fontSize: defaultFontSize);

// Define overall app brightness and color scheme
final defaultTheme = ThemeData(
    // brightness: Brightness.dark,
    scaffoldBackgroundColor: bgColor,
    primarySwatch: Colors.red,
    primaryColor: mainColor,
    backgroundColor: bgColor,
    fontFamily: defaultFontFamily,
    textTheme: TextTheme(bodyText2: defaultTextStyle),
    appBarTheme: AppBarTheme(
      color: bgColor,
      iconTheme: IconThemeData(color: mainColor),
    ));
