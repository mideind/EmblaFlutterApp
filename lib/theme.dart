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

// Configure app theme: colors, fonts and other styling

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import './util.dart';

final mainColor = HexColor.fromHex('#e83939');
final bgColor = HexColor.fromHex('#f9f9f9');

// Session button circle colors, outermost to innermost
final circleColor1 = HexColor.fromHex("#f9f0f0");
final circleColor2 = HexColor.fromHex("#f9e2e1");
final circleColor3 = HexColor.fromHex("#f9dcdb");

const Brightness defaultBrightness = Brightness.light;

const String defaultFontFamily = 'Lato';
const double defaultFontSize = 18.0;
const double sessionFontSize = 24.0;

final TextStyle defaultTextStyle = TextStyle(color: mainColor, fontSize: defaultFontSize);
final TextStyle sessionTextStyle =
    TextStyle(color: mainColor, fontSize: sessionFontSize, fontStyle: FontStyle.italic);

// Define overall app brightness and color scheme
final defaultTheme = ThemeData(
    // brightness: Brightness.dark,
    // accentColor: Colors.cyan[600],
    scaffoldBackgroundColor: bgColor,
    primarySwatch: Colors.red,
    primaryColor: mainColor,
    backgroundColor: bgColor,
    fontFamily: defaultFontFamily,
    textTheme: TextTheme(bodyText2: defaultTextStyle),
    appBarTheme: AppBarTheme(
      brightness: defaultBrightness,
      color: bgColor,
      textTheme: TextTheme().apply(displayColor: mainColor),
      iconTheme: IconThemeData(color: mainColor),
    ));
