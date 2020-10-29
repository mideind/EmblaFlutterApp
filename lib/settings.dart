/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2020 Miðeind ehf.
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

// Settings view

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import './prefs.dart' show Prefs;
import './common.dart' show dlog;

class SettingsSwitchWidget extends StatefulWidget {
  final String prefKey;
  final String label;

  SettingsSwitchWidget({Key key, this.label, this.prefKey}) : super(key: key);

  @override
  _SettingsSwitchWidgetState createState() => _SettingsSwitchWidgetState(this.label, this.prefKey);
}

class _SettingsSwitchWidgetState extends State<SettingsSwitchWidget> {
  String prefKey;
  String label;

  _SettingsSwitchWidgetState(String lab, String key) {
    this.label = lab;
    this.prefKey = key;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: MergeSemantics(
        child: ListTile(
          title: Text(this.label, style: TextStyle(fontSize: 18.0)),
          trailing: CupertinoSwitch(
            value: Prefs().boolForKey(this.prefKey),
            activeColor: Colors.red,
            onChanged: (bool value) {
              setState(() {
                if (this.prefKey == 'privacy_mode' && value) {
                  Prefs().setBoolForKey('share_location', false);
                } else if (this.prefKey == 'share_location' && value) {
                  Prefs().setBoolForKey('privacy_mode', false);
                }
                dlog("Setting prefs key ${this.prefKey} to $value");
                Prefs().setBoolForKey(this.prefKey, value);
              });
            },
          ),
          onTap: () {
            setState(() {
              Prefs().setBoolForKey(this.prefKey, !Prefs().boolForKey(this.prefKey));
            });
          },
        ),
      ),
    );
  }
}

class SettingsSegmentedWidget extends StatefulWidget {
  final String label;
  final List<String> items;
  final String prefKey;

  SettingsSegmentedWidget({Key key, this.label, this.items, this.prefKey}) : super(key: key);

  @override
  _SettingsSegmentedWidgetState createState() =>
      _SettingsSegmentedWidgetState(this.label, this.items, this.prefKey);
}

class _SettingsSegmentedWidgetState extends State<SettingsSwitchWidget> {
  String label;
  List<String> items;
  String prefKey;

  _SettingsSegmentedWidgetState(String lab, List<String> it, String key) {
    this.label = lab;
    this.items = it;
    this.prefKey = key;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: MergeSemantics(
        child: ListTile(
          title: Text(this.label),
          trailing: CupertinoSegmentedControl(
              children: const <int, Widget>{
                0: Padding(padding: EdgeInsets.all(10.0), child: Text('Kona')),
                1: Padding(padding: EdgeInsets.all(10.0), child: Text('Karl')),
              },
              groupValue: Prefs().boolForKey(this.prefKey) ? 1 : 0,
              onValueChanged: (value) {
                Prefs().setStringForKey(this.prefKey, value);
              }),
        ),
      ),
    );
  }
}

var settingsList = ListView(padding: const EdgeInsets.all(8), children: <Widget>[
  SettingsSwitchWidget(label: 'Raddvirkjun', prefKey: 'voice_activation'),
  SettingsSwitchWidget(label: 'Deila staðsetningu', prefKey: 'share_location'),
  SettingsSwitchWidget(label: 'Einkahamur', prefKey: 'privacy_mode'),
  ListTile(
    title: Text('Rödd', style: TextStyle(fontSize: 18.0)),
    trailing: CupertinoSegmentedControl(
        children: const <int, Widget>{
          0: Padding(padding: EdgeInsets.all(8.0), child: Text('Kona')),
          1: Padding(padding: EdgeInsets.all(8.0), child: Text('Karl')),
        },
        groupValue: Prefs().boolForKey('voice_id') ? 1 : 0,
        onValueChanged: (value) {
          Prefs().setStringForKey('voice_id', value);
        }),
  ),
  ListTile(
      title: Text('Talhraði', style: TextStyle(fontSize: 18.0)),
      trailing: CupertinoSlider(onChanged: (double value) {}, value: 50, min: 0, max: 100)),
  TextButton(
    onPressed: () {},
    child: Text('Hreinsa fyrirspurnasögu', style: TextStyle(fontSize: 18.0)),
  ),
  TextButton(
    onPressed: () {},
    child: Text('Hreinsa öll gögn', style: TextStyle(fontSize: 18.0)),
  ),
  Padding(
      padding: EdgeInsets.all(8.0),
      child: TextFormField(
        initialValue: Prefs().stringForKey('query_server'),
        style: TextStyle(fontSize: 18.0),
        onChanged: (var val) {
          Prefs().setStringForKey('query_server', val);
        },
      )),
  CupertinoSegmentedControl(
      children: const <int, Widget>{
        0: Padding(padding: EdgeInsets.all(8.0), child: Text('Greynir')),
        1: Padding(padding: EdgeInsets.all(8.0), child: Text('Brandur')),
        2: Padding(padding: EdgeInsets.all(8.0), child: Text('Vinna')),
        3: Padding(padding: EdgeInsets.all(8.0), child: Text('Heima')),
      },
      groupValue: 0,
      onValueChanged: (value) {
        // Do something
      }),
]);

class SettingsRoute extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          // title: Text(
          //   'Stillingar',
          //   style: TextStyle(color: Colors.red),
          // ),
          //backgroundColor: Colors.transparent,
          bottomOpacity: 0.0,
          elevation: 0.0,
          toolbarOpacity: 1.0,
        ),
        body: settingsList);
  }
}
