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

// Settings route

import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';

import './common.dart';
import './query.dart' show QueryService;
import './prefs.dart' show Prefs;
import './theme.dart';

// UI string constants
const String kPrivacyModeMessage =
    'Í einkaham sendir forritið engar upplýsingar frá sér að fyrirspurnatexta undanskildum. '
    'Þetta kemur í veg fyrir að fyrirspurnaþjónn geti nýtt staðsetningu, fyrri spurningar, '
    'gerð tækis o.fl. til þess að bæta svör.';

const String kClearHistoryAlertText =
    'Þessi aðgerð hreinsar alla fyrirspurnasögu þessa tækis. Fyrirspurnir eru aðeins vistaðar '
    'í 30 daga og gögnin einungis nýtt til þess að bæta svör.';

const String kClearAllAlertText =
    'Þessi aðgerð hreinsar öll gögn Emblu sem tengjast þessu tæki. Gögnin eru einungis nýtt '
    'til þess að bæta svör.';

// Switch control widget associated with a boolean value pref
class SettingsSwitchWidget extends StatefulWidget {
  final String label;
  final String prefKey;

  SettingsSwitchWidget({Key key, this.label, this.prefKey}) : super(key: key);

  @override
  _SettingsSwitchWidgetState createState() => _SettingsSwitchWidgetState();
}

class _SettingsSwitchWidgetState extends State<SettingsSwitchWidget> {
  @override
  Widget build(BuildContext context) {
    String prefKey = this.widget.prefKey;
    return Container(
      child: MergeSemantics(
        child: ListTile(
          title: Text(this.widget.label, style: menuTextStyle),
          trailing: CupertinoSwitch(
            value: Prefs().boolForKey(prefKey),
            activeColor: mainColor,
            onChanged: (bool value) {
              setState(() {
                Prefs().setBoolForKey(prefKey, value);
              });
            },
          ),
          onTap: () {
            setState(() {
              Prefs().setBoolForKey(prefKey, !Prefs().boolForKey(prefKey));
            });
          },
        ),
      ),
    );
  }
}

// Switch control associated with a boolean value pref, presents a confirmation alert prompt
class SettingsSwitchConfirmWidget extends StatefulWidget {
  final String label;
  final String prefKey;

  SettingsSwitchConfirmWidget({Key key, this.label, this.prefKey}) : super(key: key);

  @override
  _SettingsSwitchConfirmWidgetState createState() => _SettingsSwitchConfirmWidgetState();
}

class _SettingsSwitchConfirmWidgetState extends State<SettingsSwitchConfirmWidget> {
  Future<void> _showPromptDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Virkja einkaham?'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(kPrivacyModeMessage),
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
              child: Text('Virkja'),
              onPressed: () {
                setState(() {
                  Prefs().setBoolForKey(this.widget.prefKey, true);
                });
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
    String prefKey = this.widget.prefKey;
    return Container(
      child: MergeSemantics(
        child: ListTile(
          title: Text(this.widget.label, style: menuTextStyle),
          trailing: CupertinoSwitch(
            value: Prefs().boolForKey(prefKey),
            activeColor: mainColor,
            onChanged: (bool value) {
              if (value == true) {
                _showPromptDialog(context);
              } else {
                setState(() {
                  Prefs().setBoolForKey(prefKey, false);
                });
              }
            },
          ),
          onTap: () {
            if (Prefs().boolForKey(prefKey) == false) {
              _showPromptDialog(context);
            } else {
              setState(() {
                Prefs().setBoolForKey(prefKey, true);
              });
            }
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
  _SettingsSegmentedWidgetState createState() => _SettingsSegmentedWidgetState();
}

class _SettingsSegmentedWidgetState extends State<SettingsSegmentedWidget> {
  Map<int, Widget> _genChildren() {
    List<String> items = this.widget.items;
    Map<int, Widget> wlist = {};
    for (int i = 0; i < items.length; i++) {
      wlist[i] = Padding(padding: EdgeInsets.all(10.0), child: Text(items[i]));
    }
    return wlist;
  }

  int selectedSegment() {
    List<String> items = this.widget.items;
    String prefKey = this.widget.prefKey;
    for (int i = 0; i < items.length; i++) {
      if (Prefs().stringForKey(prefKey) == items[i]) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: ListTile(
        title: Text(this.widget.label, style: menuTextStyle),
        trailing: CupertinoSegmentedControl(
            children: _genChildren(),
            groupValue: selectedSegment(),
            onValueChanged: (value) {
              setState(() {
                Prefs().setStringForKey(this.widget.prefKey, this.widget.items[value]);
              });
            }),
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
  final double stepSize;

  SettingsSliderWidget(
      {Key key, this.label, this.prefKey, this.minValue, this.maxValue, this.stepSize})
      : super(key: key);

  @override
  _SettingsSliderWidgetState createState() => _SettingsSliderWidgetState();
}

class _SettingsSliderWidgetState extends State<SettingsSliderWidget> {
  double currVal;

  double _constrainValue(double pval) {
    pval = pval > this.widget.maxValue ? this.widget.maxValue : pval;
    pval = pval < this.widget.minValue ? this.widget.maxValue : pval;
    if (this.widget.stepSize > 0) {
      pval = (pval / this.widget.stepSize).round() * this.widget.stepSize;
    }
    return pval;
  }

  String genSliderLabel() {
    double val = Prefs().floatForKey(this.widget.prefKey);
    String valStr = val.toStringAsFixed(2);
    if (valStr.endsWith("0")) {
      valStr = valStr.substring(0, valStr.length - 1);
    }
    valStr = valStr.replaceAll('.', ',');
    return "${this.widget.label} (${valStr}x)";
  }

  @override
  Widget build(BuildContext context) {
    this.currVal = _constrainValue(Prefs().floatForKey(this.widget.prefKey));
    return ListTile(
        title: Text(genSliderLabel(), style: menuTextStyle),
        trailing: CupertinoSlider(
            onChanged: (double value) {
              setState(() {
                currVal = _constrainValue(value);
                Prefs().setFloatForKey(this.widget.prefKey, currVal);
              });
            },
            value: this.currVal,
            min: this.widget.minValue,
            max: this.widget.maxValue));
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

  Future<void> _showPromptDialog(BuildContext context) async {
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
        _showPromptDialog(context);
      },
      child: Text(this.label, style: TextStyle(color: mainColor, fontSize: defaultFontSize)),
    );
  }
}

// Widget that controls query server prefs i.e. text field + preset buttons
class QueryServerSegmentedWidget extends StatefulWidget {
  final List items;
  final String prefKey;

  QueryServerSegmentedWidget({Key key, this.items, this.prefKey}) : super(key: key);

  @override
  _QueryServerSegmentedWidgetState createState() => _QueryServerSegmentedWidgetState();
}

class _QueryServerSegmentedWidgetState extends State<QueryServerSegmentedWidget> {
  String text;
  TextEditingController textController;

  @override
  void initState() {
    super.initState();
    textController = TextEditingController(text: Prefs().stringForKey("query_server"));
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  Map<int, Widget> _genChildren() {
    Map<int, Widget> wlist = {};
    for (int i = 0; i < this.widget.items.length; i++) {
      wlist[i] = Padding(padding: EdgeInsets.all(10.0), child: Text(this.widget.items[i][0]));
    }
    return wlist;
  }

  int selectedSegment() {
    for (int i = 0; i < this.widget.items.length; i++) {
      if (Prefs().stringForKey(this.widget.prefKey) == this.widget.items[i][1]) {
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
      finalVal = this.widget.items[val][1];
    }

    setState(() {
      this.text = finalVal;
      Prefs().setStringForKey(this.widget.prefKey, this.text);
      textController.value = TextEditingValue(
          text: this.text,
          selection: TextSelection(baseOffset: this.text.length, extentOffset: this.text.length));
    });
  }

  @override
  Widget build(BuildContext context) {
    this.text = Prefs().stringForKey(this.widget.prefKey);
    return Column(children: [
      Padding(
          padding: EdgeInsets.all(8.0),
          child: TextField(controller: textController, style: menuTextStyle, onChanged: _changed)),
      CupertinoSegmentedControl(
          children: _genChildren(), groupValue: selectedSegment(), onValueChanged: _changed),
    ]);
  }
}

class SettingsLabelValueWidget extends StatelessWidget {
  SettingsLabelValueWidget(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
        child: MergeSemantics(
            child: ListTile(
      title: Text(this.label, style: menuTextStyle),
      trailing: Text(this.value, style: menuTextStyle),
    )));
  }
}

// List of settings widgets
List<Widget> _settings() {
  return <Widget>[
    SettingsSwitchWidget(label: 'Raddvirkjun', prefKey: 'hotword_activation'),
    SettingsSwitchWidget(label: 'Deila staðsetningu', prefKey: 'share_location'),
    SettingsSwitchConfirmWidget(label: 'Einkahamur', prefKey: 'privacy_mode'),
    SettingsSegmentedWidget(label: 'Rödd', items: ['Karl', 'Kona'], prefKey: 'voice_id'),
    SettingsSliderWidget(
        label: 'Talhraði',
        prefKey: 'voice_speed',
        minValue: kVoiceSpeedMin,
        maxValue: kVoiceSpeedMax,
        stepSize: 0.05),
    SettingsLabelValueWidget(
        'Útgáfa', "$kSoftwareName $kSoftwareVersion (${Platform.operatingSystem})"),
    SettingsButtonWidget(
        label: 'Hreinsa fyrirspurnasögu',
        alertText: kClearHistoryAlertText,
        buttonTitle: 'Hreinsa',
        handler: () {
          QueryService.clearUserData(false);
        }),
    SettingsButtonWidget(
        label: 'Hreinsa öll gögn',
        alertText: kClearAllAlertText,
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
      slist.addAll([
        // SettingsSegmentedWidget(
        //     label: 'Talgreining', items: ['Google', 'Tíró'], prefKey: 'speech2text_server'),
        QueryServerSegmentedWidget(items: kQueryServerPresetOptions, prefKey: 'query_server'),
      ]);
    }

    return Scaffold(
        appBar: standardAppBar, body: ListView(padding: const EdgeInsets.all(8), children: slist));
  }
}
