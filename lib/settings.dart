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

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import './prefs.dart' show Prefs;
import './common.dart';

List queryServerItems = [
  ['Greynir', 'https://greynir.is'],
  ['Brandur', 'http://brandur.mideind.is:5000'],
  ['Vinna', 'http://192.168.1.114:5000'],
  ['Heima', 'http://192.168.1.8:5000']
];

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

class _SettingsSegmentedWidgetState extends State<SettingsSegmentedWidget> {
  String label;
  List<String> items;
  String prefKey;

  _SettingsSegmentedWidgetState(String lab, List<String> it, String key) {
    this.label = lab;
    this.items = it;
    this.prefKey = key;
  }

  Map<int, Widget> _genChildren() {
    Map<int, Widget> wlist = {};
    for (int i = 0; i < this.items.length; i++) {
      wlist[i] = Padding(padding: EdgeInsets.all(10.0), child: Text(this.items[i]));
    }
    return wlist;
  }

  int selectedSegment() {
    for (int i = 0; i < this.items.length; i++) {
      if (Prefs().stringForKey(this.prefKey) == this.items[i]) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: MergeSemantics(
        child: ListTile(
          title: Text(this.label),
          trailing: CupertinoSegmentedControl(
              children: _genChildren(),
              groupValue: selectedSegment(),
              onValueChanged: (value) {
                setState(() {
                  Prefs().setStringForKey(this.prefKey, this.items[value]);
                });
              }),
        ),
      ),
    );
  }
}

class QueryServerSegmentedWidget extends StatefulWidget {
  final List items;
  final String prefKey;

  QueryServerSegmentedWidget({Key key, this.items, this.prefKey}) : super(key: key);

  @override
  _QueryServerSegmentedWidgetState createState() =>
      _QueryServerSegmentedWidgetState(this.items, this.prefKey);
}

class _QueryServerSegmentedWidgetState extends State<QueryServerSegmentedWidget> {
  List items;
  String prefKey;
  String text;
  final textController = TextEditingController();

  _QueryServerSegmentedWidgetState(List it, String key) {
    this.items = it;
    this.prefKey = key;
    this.text = Prefs().stringForKey(key);
  }

  Map<int, Widget> _genChildren() {
    Map<int, Widget> wlist = {};
    for (int i = 0; i < this.items.length; i++) {
      wlist[i] = Padding(padding: EdgeInsets.all(10.0), child: Text(this.items[i][0]));
    }
    return wlist;
  }

  int selectedSegment() {
    for (int i = 0; i < this.items.length; i++) {
      if (Prefs().stringForKey(this.prefKey) == this.items[i][1]) {
        return i;
      }
    }
    return 0;
  }

  void _changed(var val) {
    String finalVal = '';
    if (val is String) {
      finalVal = val;
    } else {
      finalVal = this.items[val][1];
    }
    setState(() {
      this.text = finalVal;
      Prefs().setStringForKey(this.prefKey, this.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    textController.text = text;
    return Column(children: [
      Padding(
          padding: EdgeInsets.all(8.0),
          child: TextField(
              controller: textController, style: TextStyle(fontSize: 18.0), onChanged: _changed)),
      CupertinoSegmentedControl(
          children: _genChildren(), groupValue: selectedSegment(), onValueChanged: _changed),
    ]);
  }
}

class SettingsSliderWidget extends StatefulWidget {
  final String label;
  final String prefKey;
  final double minValue;
  final double maxValue;

  SettingsSliderWidget({Key key, this.label, this.prefKey, this.minValue, this.maxValue})
      : super(key: key);

  @override
  _SettingsSliderWidgetState createState() =>
      _SettingsSliderWidgetState(this.label, this.prefKey, this.minValue, this.maxValue);
}

class _SettingsSliderWidgetState extends State<SettingsSliderWidget> {
  String label;
  String prefKey;
  double minValue;
  double maxValue;
  double currVal;

  _SettingsSliderWidgetState(String lab, String key, double minv, double maxv) {
    this.label = lab;
    this.prefKey = key;
    this.minValue = minv;
    this.maxValue = maxv;
    this.currVal = _validValue(Prefs().floatForKey(key));
  }

  double _validValue(double pval) {
    if (pval > this.maxValue) {
      pval = maxValue;
    }
    if (pval < this.minValue) {
      pval = minValue;
    }
    return pval;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
        title: Text(this.label, style: TextStyle(fontSize: 18.0)),
        trailing: CupertinoSlider(
            onChanged: (double value) {
              setState(() {
                this.currVal = value;
                Prefs().setFloatForKey(this.prefKey, value);
              });
            },
            value: this.currVal,
            min: this.minValue,
            max: this.maxValue));
  }
}

List<Widget> _settings() {
  return <Widget>[
    SettingsSwitchWidget(label: 'Raddvirkjun', prefKey: 'voice_activation'),
    SettingsSwitchWidget(label: 'Deila staðsetningu', prefKey: 'share_location'),
    SettingsSwitchWidget(label: 'Einkahamur', prefKey: 'privacy_mode'),
    SettingsSegmentedWidget(label: 'Rödd', items: ['Karl', 'Kona'], prefKey: 'voice_id'),
    SettingsSliderWidget(
        label: 'Talhraði',
        prefKey: 'voice_speed',
        minValue: VOICE_SPEED_MIN,
        maxValue: VOICE_SPEED_MAX),
    TextButton(
      onPressed: () {},
      child: Text('Hreinsa fyrirspurnasögu', style: TextStyle(fontSize: 18.0)),
    ),
    TextButton(
      onPressed: () {},
      child: Text('Hreinsa öll gögn', style: TextStyle(fontSize: 18.0)),
    ),
  ];
}

class SettingsRoute extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    List<Widget> slist = _settings();
    if (kReleaseMode == false) {
      slist.addAll([QueryServerSegmentedWidget(items: queryServerItems, prefKey: 'query_server')]);
    }

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
        body: ListView(padding: const EdgeInsets.all(8), children: slist));
  }
}
