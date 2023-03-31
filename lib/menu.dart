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

/// Menu route

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;

import './common.dart';
import './theme.dart' show img4theme, menuTextStyle, standardAppBar, standardEdgeInsets;
import './settings.dart' show SettingsRoute;
import './web.dart' show WebViewRoute;
// import './smart/smarthome.dart' show SmarthomeRoute if (kDebugMode) "";

void _pushWebRoute(BuildContext context, dynamic arg) {
  Navigator.push(
    context,
    CupertinoPageRoute(
      builder: (context) => WebViewRoute(initialURL: arg as String),
    ),
  );
}

void _pushSettingsRoute(BuildContext context, dynamic arg) {
  Navigator.push(
    context,
    CupertinoPageRoute(
      builder: (context) => const SettingsRoute(),
    ),
  );
}

// void _pushSmarthomeRoute(BuildContext context, dynamic arg) {
//   Navigator.push(
//     context,
//     CupertinoPageRoute(
//       builder: (context) => const SmarthomeRoute(),
//     ),
//   );
// }

// Generate a menu tile based on args
ListTile _buildMenuTile(String name, String imageName,
    Function(BuildContext context, dynamic arg) onTapFunc, BuildContext ctx, dynamic arg) {
  return ListTile(
    title: Text(name, style: menuTextStyle),
    leading: Image(image: img4theme(imageName, ctx)),
    trailing: const Icon(Icons.arrow_right),
    onTap: () {
      onTapFunc(ctx, arg);
    },
  );
}

// Generate list view with menu tiles
ListView _buildMenu(BuildContext context) {
  final List<ListTile> menuItems = [
    _buildMenuTile('Stillingar', 'cog', _pushSettingsRoute, context, null),
    _buildMenuTile('Um Emblu', 'cube', _pushWebRoute, context, kAboutURL),
    _buildMenuTile('Leiðbeiningar', 'cube', _pushWebRoute, context, kInstructionsURL),
    _buildMenuTile('Persónuvernd', 'cube', _pushWebRoute, context, kPrivacyURL),
  ];

  // Only show Smart Home menu tile in debug mode
  // if (kDebugMode) {
  //   final ListTile smarthomeTile =
  //       _buildMenuTile('Snjallheimili', 'smarthome', _pushSmarthomeRoute, context, null);
  //   menuItems.insert(1, smarthomeTile); // Insert below Settings menu item
  // }

  return ListView(
    padding: standardEdgeInsets,
    children: menuItems,
  );
}

class MenuRoute extends StatelessWidget {
  const MenuRoute({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: standardAppBar, body: _buildMenu(context));
  }
}
