/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2020-2023 Miðeind ehf. <mideind@mideind.is>
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

// Configure app theme i.e. colors, fonts and other styling

import 'package:flutter/material.dart';

import './util.dart' show HexColor;

// Define default font family and sizes
const String defaultFontFamily = 'Lato';
const double defaultFontSize = 18.0;
const double sessionFontSize = 23.0;

// Define default text styles for UI elements
const menuTextStyle = TextStyle(fontSize: defaultFontSize);
const sessionTextStyle = TextStyle(fontSize: sessionFontSize, fontStyle: FontStyle.italic);

// Session button colors, outermost to innermost
final Color circleColor1 = HexColor.fromHex('#f9f0f0');
final Color circleColor2 = HexColor.fromHex('#f9e2e1');
final Color circleColor3 = HexColor.fromHex('#f9dcdb');
final Color topWaveformColor = HexColor.fromHex('#e83939');
final Color bottomWaveformColor = HexColor.fromHex('#f2918f');

// Define default (light) app styling and color scheme
final Color lightMainColor = HexColor.fromHex('#e83939');
final Color lightBgColor = HexColor.fromHex('#f9f9f9');
final Color lightTextColor = HexColor.fromHex('#202020');
final Color lightCardColor = HexColor.fromHex('#ffffff');
final Color lightSplashColor = HexColor.fromHex('#f6b0b0');

final lightThemeData = ThemeData(
  // useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.red, brightness: Brightness.light)
      .copyWith(surface: lightBgColor),
  scaffoldBackgroundColor: lightBgColor,
  primaryColor: lightMainColor,
  cardColor: lightCardColor,
  splashColor: lightSplashColor,
  fontFamily: defaultFontFamily,
  textTheme: TextTheme(
    titleSmall: TextStyle(color: lightTextColor, fontSize: defaultFontSize),
    titleMedium: TextStyle(color: lightTextColor, fontSize: defaultFontSize),
    titleLarge: TextStyle(color: lightTextColor, fontSize: defaultFontSize),
    labelSmall: TextStyle(color: lightTextColor, fontSize: defaultFontSize),
    labelLarge: TextStyle(color: lightTextColor, fontSize: defaultFontSize),
    bodySmall: TextStyle(color: lightTextColor, fontSize: defaultFontSize),
    bodyMedium: TextStyle(color: lightMainColor, fontSize: defaultFontSize),
    bodyLarge: TextStyle(color: lightMainColor, fontSize: defaultFontSize),
    displaySmall: TextStyle(color: lightTextColor, fontSize: defaultFontSize),
    displayMedium: TextStyle(color: lightTextColor, fontSize: defaultFontSize),
    displayLarge: TextStyle(color: lightTextColor, fontSize: defaultFontSize),
    headlineLarge: TextStyle(color: lightTextColor, fontSize: defaultFontSize),
    headlineMedium: TextStyle(color: lightTextColor, fontSize: defaultFontSize),
    headlineSmall: TextStyle(color: lightTextColor, fontSize: defaultFontSize),
  ),
  appBarTheme: AppBarTheme(
    color: lightBgColor,
    iconTheme: IconThemeData(color: lightMainColor),
  ),
);

// Define dark mode app styling and color scheme
final darkMainColor = HexColor.fromHex('#f7f7f7');
final darkBgColor = HexColor.fromHex('#202020');
final darkCardColor = HexColor.fromHex('#505050');
const darkSplashColor = Color.fromRGBO(0, 0, 0, 0.1);

final darkThemeData = ThemeData(
  // useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.grey, brightness: Brightness.dark)
      .copyWith(surface: darkBgColor),
  scaffoldBackgroundColor: darkBgColor,
  primaryColor: darkMainColor,
  cardColor: darkCardColor,
  splashColor: darkSplashColor,
  fontFamily: defaultFontFamily,
  textTheme: TextTheme(
    titleSmall: TextStyle(color: darkMainColor, fontSize: defaultFontSize),
    titleMedium: TextStyle(color: darkMainColor, fontSize: defaultFontSize),
    titleLarge: TextStyle(color: darkMainColor, fontSize: defaultFontSize),
    labelSmall: TextStyle(color: darkMainColor, fontSize: defaultFontSize),
    labelLarge: TextStyle(color: darkMainColor, fontSize: defaultFontSize),
    bodySmall: TextStyle(color: darkMainColor, fontSize: defaultFontSize),
    bodyMedium: TextStyle(color: darkMainColor, fontSize: defaultFontSize),
    bodyLarge: TextStyle(color: darkMainColor, fontSize: defaultFontSize),
    displaySmall: TextStyle(color: darkMainColor, fontSize: defaultFontSize),
    displayMedium: TextStyle(color: darkMainColor, fontSize: defaultFontSize),
    displayLarge: TextStyle(color: darkMainColor, fontSize: defaultFontSize),
    headlineLarge: TextStyle(color: darkMainColor, fontSize: defaultFontSize),
    headlineMedium: TextStyle(color: darkMainColor, fontSize: defaultFontSize),
    headlineSmall: TextStyle(color: darkMainColor, fontSize: defaultFontSize),
  ),
  appBarTheme: AppBarTheme(
    color: darkBgColor,
    iconTheme: IconThemeData(color: darkMainColor),
  ),
);

// Standard app bar appearance
final standardAppBar = AppBar(
  bottomOpacity: 0.0,
  elevation: 0.0,
  toolbarOpacity: 1.0,
);

// Standard padding for routes
const standardEdgeInsets = EdgeInsets.all(8);

/// Get image for current theme
AssetImage img4theme(String imgName, BuildContext context) {
  if (MediaQuery.platformBrightnessOf(context) == Brightness.dark) {
    imgName = "${imgName}_dark";
  }
  return AssetImage("assets/images/$imgName.png");
}

/// Get the safe main color for the current theme
Color color4ctx(BuildContext context) {
  return MediaQuery.platformBrightnessOf(context) == Brightness.dark
      ? darkMainColor
      : lightMainColor;
}

/// Get circle colors for current theme
List<Color> circleColors4Context(var context) {
  if (MediaQuery.platformBrightnessOf(context) == Brightness.dark) {
    final Color circleColor1 = HexColor.fromHex('#f0f0f0');
    final Color circleColor2 = HexColor.fromHex('#e4e4e4');
    final Color circleColor3 = HexColor.fromHex('#dcdcdc');
    return [circleColor1, circleColor2, circleColor3];
  } else {
    final Color circleColor1 = HexColor.fromHex('#f9f0f0');
    final Color circleColor2 = HexColor.fromHex('#f9e2e1');
    final Color circleColor3 = HexColor.fromHex('#f9dcdb');
    return [circleColor1, circleColor2, circleColor3];
  }
}
