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

import './query.dart' show QueryService;
import './prefs.dart' show Prefs;
import './common.dart';

// Switch control associated with a boolean value pref
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

// Segmented control associated with a string value pref
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

// Slider widget associated with a pref value
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

// Button that presents an alert with an action name + handler
class SettingsButtonWidget extends StatelessWidget {
  final String label;
  final String alertText;
  final String buttonTitle;
  final handler;

  SettingsButtonWidget({Key key, this.label, this.alertText, this.buttonTitle, this.handler})
      : super(key: key);

  Future<void> _showMyDialog(var context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(this.label + '?'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(this.alertText),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Hætta við'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(this.buttonTitle),
              onPressed: () {
                this.handler();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        _showMyDialog(context);
      },
      child: Text(this.label, style: TextStyle(fontSize: 18.0)),
    );
  }
}

// Widget that controls query server prefs i.e. text field + preset buttons
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

// Alert messages for clear history buttons
String clearHistoryText = '''Þessi aðgerð hreinsar alla fyrirspurnasögu þessa tækis.
Fyrirspurnir eru aðeins vistaðar í 30 daga og gögnin einungis nýtt til þess að bæta svör.''';
String clearAllText = '''Þessi aðgerð hreinsar öll gögn Emblu sem tengjast þessu tæki.
Gögnin eru einungis nýtt til þess að bæta svör.''';

// List of settings widgets
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
    SettingsButtonWidget(
        label: 'Hreinsa fyrirspurnasögu',
        alertText: clearHistoryText,
        buttonTitle: 'Hreinsa',
        handler: () {
          QueryService.clearUserData(false);
        }),
    SettingsButtonWidget(
        label: 'Hreinsa öll gögn',
        alertText: clearAllText,
        buttonTitle: 'Hreinsa',
        handler: () {
          QueryService.clearUserData(true);
        }),
  ];
}

class SettingsRoute extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    List<Widget> slist = _settings();
    // Only include query server selection widget in debug builds
    if (kReleaseMode == false) {
      slist.addAll(
          [QueryServerSegmentedWidget(items: QUERY_SERVER_OPTIONS, prefKey: 'query_server')]);
    }

    return Scaffold(
        appBar: AppBar(
          bottomOpacity: 0.0,
          elevation: 0.0,
          toolbarOpacity: 1.0,
        ),
        body: ListView(padding: const EdgeInsets.all(8), children: slist));
  }
}
