import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

var settingsList = ListView(padding: const EdgeInsets.all(8), children: <Widget>[
  ListTile(
      title: Text('Virkja með röddu', style: TextStyle(fontSize: 18.0)),
      trailing: CupertinoSwitch(
        value: true,
        activeColor: Colors.red,
        onChanged: (bool value) {},
      )),
  ListTile(
      title: Text('Deila staðsetningu', style: TextStyle(fontSize: 18.0)),
      trailing: CupertinoSwitch(
        value: true,
        activeColor: Colors.red,
        onChanged: (bool value) {},
      )),
  ListTile(
      title: Text('Einkahamur', style: TextStyle(fontSize: 18.0)),
      trailing: CupertinoSwitch(
        value: true,
        activeColor: Colors.red,
        onChanged: (bool value) {},
      )),
  ListTile(
      title: Text('Rödd', style: TextStyle(fontSize: 18.0)),
      trailing: CupertinoSegmentedControl(
          children: const <int, Widget>{
            0: Padding(padding: EdgeInsets.all(8.0), child: Text('Kona')),
            1: Padding(padding: EdgeInsets.all(8.0), child: Text('Karl')),
          },
          groupValue: 0,
          onValueChanged: (value) {
            // Do something
          })),
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
  TextFormField(initialValue: "https://greynir.is", style: TextStyle(fontSize: 18.0)),
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
          title: Text('Stillingar'),
          //backgroundColor: Colors.transparent,
          bottomOpacity: 0.0,
          elevation: 0.0,
        ),
        body: settingsList);
  }
}
