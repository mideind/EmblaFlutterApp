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

// Settings route

import 'package:embla/version.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';

import './common.dart';
import './query.dart' show QueryService;
import './prefs.dart' show Prefs;
import './voices.dart' show VoiceSelectionRoute;
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

Divider divider = const Divider(
  height: 20,
);

/// Switch control widget associated with a boolean value pref
class SettingsSwitchWidget extends StatefulWidget {
  final String label;
  final String prefKey;

  const SettingsSwitchWidget({Key? key, required this.label, required this.prefKey})
      : super(key: key);

  @override
  SettingsSwitchWidgetState createState() => SettingsSwitchWidgetState();
}

class SettingsSwitchWidgetState extends State<SettingsSwitchWidget> {
  @override
  Widget build(BuildContext context) {
    String prefKey = widget.prefKey;
    return MergeSemantics(
      child: ListTile(
        title: Text(widget.label),
        trailing: CupertinoSwitch(
          value: Prefs().boolForKey(prefKey),
          activeColor: Theme.of(context).primaryColor,
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
    );
  }
}

/// Special switch control for privacy mode, presents a confirmation alert prompt
class SettingsPrivacySwitchWidget extends StatefulWidget {
  final String label;
  final String prefKey;

  const SettingsPrivacySwitchWidget({Key? key, required this.label, required this.prefKey})
      : super(key: key);

  @override
  SettingsPrivacySwitchWidgetState createState() => SettingsPrivacySwitchWidgetState();
}

class SettingsPrivacySwitchWidgetState extends State<SettingsPrivacySwitchWidget> {
  Future<void> _showPromptDialog(BuildContext context) async {
    return showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
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
                  Prefs().setBoolForKey(widget.prefKey, true);
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
    String prefKey = widget.prefKey;
    return MergeSemantics(
      child: ListTile(
        title: Text(widget.label),
        trailing: CupertinoSwitch(
          value: Prefs().boolForKey(prefKey),
          activeColor: Theme.of(context).primaryColor,
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
    );
  }
}

/// Slider widget associated with a pref float value
class SettingsSliderWidget extends StatefulWidget {
  final String label;
  final String prefKey;
  final double minValue;
  final double maxValue;
  final double stepSize;

  const SettingsSliderWidget(
      {Key? key,
      required this.label,
      required this.prefKey,
      required this.minValue,
      required this.maxValue,
      required this.stepSize})
      : super(key: key);

  @override
  SettingsSliderWidgetState createState() => SettingsSliderWidgetState();
}

class SettingsSliderWidgetState extends State<SettingsSliderWidget> {
  double currVal = 1.0;

  double _constrainValue(double pval) {
    pval = pval > widget.maxValue ? widget.maxValue : pval;
    pval = pval < widget.minValue ? widget.maxValue : pval;
    if (widget.stepSize > 0) {
      pval = (pval / widget.stepSize).round() * widget.stepSize;
    }
    return pval;
  }

  String genSliderLabel() {
    double val = Prefs().floatForKey(widget.prefKey) ?? 1.0;
    String valStr = val.toStringAsFixed(2);
    if (valStr.endsWith("0")) {
      valStr = valStr.substring(0, valStr.length - 1);
    }
    valStr = valStr.replaceAll('.', ',');
    return "${widget.label} (${valStr}x)";
  }

  @override
  Widget build(BuildContext context) {
    currVal = _constrainValue(Prefs().floatForKey(widget.prefKey) ?? 1.0);
    return ListTile(
        title: Text(genSliderLabel()),
        trailing: CupertinoSlider(
            onChanged: (double value) {
              setState(() {
                currVal = _constrainValue(value);
                Prefs().setFloatForKey(widget.prefKey, currVal);
              });
            },
            value: currVal,
            min: widget.minValue,
            max: widget.maxValue));
  }
}

/// Button that presents an alert with an action name + handler
class SettingsButtonPromptWidget extends StatelessWidget {
  final String label;
  final String alertText;
  final String buttonTitle;
  final Function handler;

  const SettingsButtonPromptWidget(
      {Key? key,
      required this.label,
      required this.alertText,
      required this.buttonTitle,
      required this.handler})
      : super(key: key);

  Future<void> _showPromptDialog(BuildContext context) async {
    return showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text("$label?"),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(alertText),
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
              child: Text(buttonTitle),
              onPressed: () {
                handler();
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
      child: Padding(
          padding: EdgeInsets.only(top: 15, bottom: 15),
          child: Text(label, style: TextStyle(fontSize: defaultFontSize))),
    );
  }
}

/// Widget that controls query server prefs i.e. text field
/// and the presets presented in a segmented control.
class QueryServerSegmentedWidget extends StatefulWidget {
  final List<List<String>> items;
  final String prefKey;

  const QueryServerSegmentedWidget({Key? key, required this.items, required this.prefKey})
      : super(key: key);

  @override
  QueryServerSegmentedWidgetState createState() => QueryServerSegmentedWidgetState();
}

class QueryServerSegmentedWidgetState extends State<QueryServerSegmentedWidget> {
  String text = "";
  TextEditingController? textController;

  @override
  void initState() {
    super.initState();
    textController = TextEditingController(text: Prefs().stringForKey("query_server"));
  }

  @override
  void dispose() {
    textController?.dispose();
    super.dispose();
  }

  Map<int, Widget> _genChildren() {
    Map<int, Widget> wlist = {};
    for (int i = 0; i < widget.items.length; i++) {
      wlist[i] = Padding(padding: EdgeInsets.all(10.0), child: Text(widget.items[i][0]));
    }
    return wlist;
  }

  int selectedSegment() {
    for (int i = 0; i < widget.items.length; i++) {
      if (Prefs().stringForKey(widget.prefKey) == widget.items[i][1]) {
        return i;
      }
    }
    return 0;
  }

  void _onChange(var val) {
    String finalVal = '';
    if (val is String) {
      finalVal = val;
    } else {
      finalVal = widget.items[val][1];
    }

    setState(() {
      text = finalVal;
      Prefs().setStringForKey(widget.prefKey, text);
      textController?.value = TextEditingValue(
          text: text, selection: TextSelection(baseOffset: text.length, extentOffset: text.length));
    });
  }

  @override
  Widget build(BuildContext context) {
    text = Prefs().stringForKey(widget.prefKey) ?? '';
    return Column(children: [
      Padding(
          padding: EdgeInsets.all(8.0),
          child: TextField(controller: textController, onSubmitted: _onChange)),
      CupertinoSegmentedControl(
          children: _genChildren(), groupValue: selectedSegment(), onValueChanged: _onChange),
    ]);
  }
}

/// Widget that displays a label and a value
class SettingsLabelValueWidget extends StatelessWidget {
  const SettingsLabelValueWidget(this.label, this.value, {this.onTapRoute, Key? key})
      : super(key: key);

  final String label;
  final String value;
  final dynamic onTapRoute;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
        child: ListTile(
      title: Text(label, style: Theme.of(context).textTheme.bodySmall),
      trailing: Text(value, style: Theme.of(context).textTheme.bodySmall),
      onTap: () {
        if (onTapRoute != null) {
          Navigator.push(
            context,
            CupertinoPageRoute(builder: (context) {
              return onTapRoute;
            }),
          );
        }
      },
    ));
  }
}

class SettingsFullTextLabelWidget extends StatelessWidget {
  const SettingsFullTextLabelWidget(this.label, {Key? key}) : super(key: key);
  final String label;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
        child: ListTile(
      title: Text(label, style: Theme.of(context).textTheme.bodySmall),
    ));
  }
}

/// Widget that displays a label and a value that is fetched asynchronously
class SettingsAsyncFullTextLabelWidget extends StatelessWidget {
  final Future<String> future;

  const SettingsAsyncFullTextLabelWidget(this.future, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
        future: future,
        builder: (context, AsyncSnapshot<String> snapshot) {
          if (snapshot.hasData) {
            return SettingsFullTextLabelWidget(snapshot.data!);
          }
          return SettingsFullTextLabelWidget('…');
        });
  }
}

/// Widget that displays a label and a value that is fetched asynchronously
class SettingsAsyncLabelValueWidget extends StatelessWidget {
  final String label;
  final Future<String> future;
  final Widget? onTapRoute;

  const SettingsAsyncLabelValueWidget(this.label, this.future, {this.onTapRoute, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
        future: future,
        builder: (context, AsyncSnapshot<String> snapshot) {
          if (snapshot.hasData) {
            return SettingsLabelValueWidget(label, snapshot.data!, onTapRoute: onTapRoute);
          }
          return SettingsLabelValueWidget(label, '…');
        });
  }
}

/// Voice selection widget
class SettingsVoiceSelectionWidget extends StatefulWidget {
  final String label;
  const SettingsVoiceSelectionWidget({Key? key, required this.label}) : super(key: key);

  @override
  SettingsVoiceSelectionWidgetState createState() => SettingsVoiceSelectionWidgetState();
}

class SettingsVoiceSelectionWidgetState extends State<SettingsVoiceSelectionWidget> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
        title: Text(widget.label, style: menuTextStyle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(Prefs().stringForKey('voice_id') ?? "(engin rödd valin)",
                style: Theme.of(context).textTheme.bodySmall),
            Icon(Icons.arrow_right),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => VoiceSelectionRoute(),
            ),
          ).then((val) {
            // Trigger re-render since voice selection may have changed
            setState(() {});
          });
        });
  }
}

// Generate list of settings widgets
List<Widget> _settings(BuildContext context) {
  // Basic settings widgets
  List<Widget> settingsWidgets = [
    SettingsSwitchWidget(label: 'Raddvirkjun', prefKey: 'hotword_activation'),
    SettingsSwitchWidget(label: 'Deila staðsetningu', prefKey: 'share_location'),
    SettingsPrivacySwitchWidget(label: 'Einkahamur', prefKey: 'privacy_mode'),
    SettingsVoiceSelectionWidget(label: 'Rödd'),
    SettingsSliderWidget(
        label: 'Talhraði',
        prefKey: 'voice_speed',
        minValue: kVoiceSpeedMin,
        maxValue: kVoiceSpeedMax,
        stepSize: 0.05),
    SettingsAsyncLabelValueWidget('Útgáfa', genVersionString(), onTapRoute: VersionRoute()),
  ];

  // Only include query server selection widget in debug builds
  if (kReleaseMode == false) {
    settingsWidgets.addAll([
      divider,
      SettingsFullTextLabelWidget('Fyrirspurnaþjónn:'),
      QueryServerSegmentedWidget(items: kQueryServerPresetOptions, prefKey: 'query_server'),
      Padding(padding: EdgeInsets.only(top: 0, bottom: 0), child: Text(''))
    ]);
  }

  // Add clear history buttons
  settingsWidgets.addAll([
    divider,
    SettingsButtonPromptWidget(
        label: 'Hreinsa fyrirspurnasögu',
        alertText: kClearHistoryAlertText,
        buttonTitle: 'Hreinsa',
        handler: () {
          QueryService.clearUserData(false);
        }),
    SettingsButtonPromptWidget(
        label: 'Hreinsa öll gögn',
        alertText: kClearAllAlertText,
        buttonTitle: 'Hreinsa',
        handler: () {
          QueryService.clearUserData(true);
        }),
    Padding(padding: EdgeInsets.only(top: 30, bottom: 30), child: Text(''))
  ]);

  return settingsWidgets;
}

class SettingsRoute extends StatelessWidget {
  const SettingsRoute({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: standardAppBar,
        body: ListView(padding: const EdgeInsets.all(8), children: _settings(context)));
  }
}
