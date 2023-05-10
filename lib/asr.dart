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

/// ASR engine selection route. Subroute of SettingsRoute.

import 'package:flutter/material.dart';

import './prefs.dart' show Prefs;
import './common.dart';
import './theme.dart';

/// Build a list view of available ASR engines
/// TODO: This is a copy of the voice selection route. Refactor.
Widget _buildASREngineList(BuildContext context) {
  return ListView.builder(
    itemCount: kASREngines.length,
    itemBuilder: (BuildContext context, int index) {
      return ListTile(
        title: Text(kASREngines[index]),
        leading: IconButton(
            onPressed: null,
            icon: ImageIcon(
              img4theme('waveform', context),
              color: color4ctx(context),
            )),
        trailing: (kASREngines[index] == Prefs().stringForKey("asr_engine"))
            ? Icon(
                Icons.done,
                color: color4ctx(context),
              ) // Checkmark
            : null,
        onTap: () {
          Prefs().setStringForKey("asr_engine", kASREngines[index]);
          Navigator.pop(context);
        },
      );
    },
  );
}

class ASRSelectionRoute extends StatelessWidget {
  const ASRSelectionRoute({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: standardAppBar, body: _buildASREngineList(context));
  }
}
