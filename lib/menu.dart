import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import './settings.dart';
import './web.dart';

var menuContext;

final TextStyle textStyle = TextStyle(fontSize: 20.0);

void pushSettings() {
  Navigator.push(
    menuContext,
    MaterialPageRoute(
      builder: (context) => SettingsRoute(),
    ),
  );
}

void pushAbout() {
  Navigator.push(
    menuContext,
    MaterialPageRoute(
      builder: (context) => AboutRoute(),
    ),
  );
}

void pushInstructions() {
  Navigator.push(
    menuContext,
    MaterialPageRoute(
      builder: (context) => InstructionsRoute(),
    ),
  );
}

void pushPrivacy() {
  Navigator.push(
    menuContext,
    MaterialPageRoute(
      builder: (context) => PrivacyRoute(),
    ),
  );
}

var list = ListView(
  padding: const EdgeInsets.all(8),
  children: <Widget>[
    ListTile(
      title: const Text("Stillingar", style: TextStyle(fontSize: 18.0, color: Colors.red)),
      //leading: const Icon(CupertinoIcons.gear),
      leading: Image(image: AssetImage('images/cube.png')),
      trailing: Icon(Icons.arrow_right, color: Colors.red),
      onTap: pushSettings,
    ),
    ListTile(
      title: const Text("Um Emblu", style: TextStyle(fontSize: 18.0, color: Colors.red)),
      leading: Image(image: AssetImage('images/cube.png')),
      trailing: Icon(Icons.arrow_right, color: Colors.red),
      onTap: pushAbout,
    ),
    ListTile(
      title: const Text(
        "Leiðbeiningar",
        style: TextStyle(fontSize: 18.0, color: Colors.red),
      ),
      leading: Image(image: AssetImage('images/cube.png')),
      trailing: Icon(Icons.arrow_right, color: Colors.red),
      onTap: pushInstructions,
    ),
    ListTile(
      title: const Text("Persónuvernd", style: TextStyle(fontSize: 18.0, color: Colors.red)),
      leading: Image(image: AssetImage('images/cube.png')),
      trailing: Icon(Icons.arrow_right, color: Colors.red),
      onTap: pushPrivacy,
    ),
  ],
);

class MenuRoute extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    menuContext = context;
    return Scaffold(
        appBar: AppBar(
          title: const Text(""),
          // leading: const Text("Til baka"),
          backgroundColor: Colors.transparent,
          bottomOpacity: 0.0,
          elevation: 0.0,
        ),
        body: list);
  }
}
