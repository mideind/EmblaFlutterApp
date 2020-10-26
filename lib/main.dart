import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'dart:convert' show json;
import './query.dart';
import './menu.dart';
import './prefs.dart';
import './common.dart';

final defaultTheme = ThemeData(
    // Define the default brightness and colors.
    // brightness: Brightness.dark,
    // accentColor: Colors.cyan[600],
    scaffoldBackgroundColor: Color(0xFFF9F9F9),
    primarySwatch: Colors.red,
    fontFamily: 'Lato',
    primaryColor: Colors.red,
    backgroundColor: Colors.grey,
    textTheme: TextTheme(bodyText2: TextStyle(color: Colors.red, fontSize: 16.0)),
    appBarTheme: AppBarTheme(
      brightness: Brightness.light,
      color: Colors.transparent,
      textTheme: TextTheme().apply(displayColor: Colors.red),
      iconTheme: IconThemeData(color: Colors.red),
    ));

final app = MaterialApp(title: "Embla", home: MainRoute(), theme: defaultTheme);
var audioPlayer = AudioPlayer();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpClient.enableTimelineLogging = true;

  await Prefs().load();

  if (Prefs().boolForKey('launched') == null) {
    dlog("Setting default prefs on first launch");
    Prefs().setDefaults();
  }
  dlog(Prefs().desc());

  runApp(app);
}

void handleResponse(r) async {
  final j = json.decode(r.body);
  dlog(j["answer"]);
  int result = await audioPlayer.play(j["audio"]);
}

class MainRoute extends StatelessWidget {
  final toggleButton = Text('Send query');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(''),
          //backgroundColor: Colors.transparent,
          bottomOpacity: 0.0,
          elevation: 0.0,
          leading: IconButton(
            icon: ImageIcon(AssetImage('images/mic.png')),
            onPressed: () {},
          ),
          actions: <Widget>[
            // action button
            IconButton(
              icon: ImageIcon(AssetImage('images/menu.png')),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => MenuRoute()));
              },
            )
          ]),
      body: Center(
        child: Container(
            color: Colors.green,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                Text("Texti"),
                MaterialButton(
                  child: toggleButton,
                  onPressed: () {
                    QueryService.sendQuery(["hvað er klukkan"], handleResponse);
                  },
                ),
              ],
            )),
      ),
    );
  }
}
