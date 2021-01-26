// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:geofencing/geofencing.dart';
import 'package:connectivity/connectivity.dart';
import 'package:path_provider/path_provider.dart';
//import 'package:flutter/foundation.dart';
import 'dart:io';
import 'geofence_model.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String geofenceState = 'N/A';
  List<String> registeredGeofences = [];
  DateTime timeStamp;
  List<Geofence> availableGeofences = [];
  Geofence dropdownValue = Geofence(name: "Select a Geofence");
  String currentServer = "https://safe-falls-49683.herokuapp.com";
  // String currentServer = 'http://10.0.2.2:5000/geofences/';
  StreamSubscription<ConnectivityResult> _connectivitySubscription;

  ReceivePort port = ReceivePort();
  final List<GeofenceEvent> triggers = <GeofenceEvent>[
    GeofenceEvent.enter,
    GeofenceEvent.dwell,
    GeofenceEvent.exit
  ];

  final AndroidGeofencingSettings androidSettings = AndroidGeofencingSettings(
      initialTrigger: <GeofenceEvent>[
        GeofenceEvent.enter,
        GeofenceEvent.exit,
        GeofenceEvent.dwell
      ],
      loiteringDelay: 1000 * 15);

  @override
  void initState() {
    super.initState();
    IsolateNameServer.registerPortWithName(
        port.sendPort, 'geofencing_send_port');

    port.listen((dynamic data) {
      print('Event: $data');

      setState(() {
        geofenceState = data;
        timeStamp = DateTime.now();
      });

      sendData(data);
      // send to the server
    });
    initPlatformState();

    getGeofences();

    startConnectivitySubscription();
    sendLogFileToServer();
  }

  Future<void> startConnectivitySubscription() async {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) async {
      if (result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi) {
        try {
          String logFile = await readLogFile();
          if (logFile != "") {
            sendLogFileToServer();
          }
        } catch (e) {
          //print(e.toString());
        }
      }
    });
  }

  Future<void> getGeofences() async {
    try {
      //String url = 'https://safe-falls-49683.herokuapp.com/geofences/';
      String url = '$currentServer/geofences/';
      final response = await http.get(url);

      List<Geofence> geofences = geofencesFromRawJson(response.body);

      setState(() {
        availableGeofences = geofences;
        dropdownValue = availableGeofences.first;
      });
    } catch (e) {
      print(e.toString());
    }
  }

  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> sendData(String dataString) async {
    try {
      //check if there's connection, if yes, send event, else, write to file

      var timeStamp = DateTime.now();
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.mobile ||
          connectivityResult == ConnectivityResult.wifi) {
        // I am connected to either mobile or wifi network
        //String url = 'https://safe-falls-49683.herokuapp.com/geofence/';

        Map<String, dynamic> data = json.decode(dataString);

        String eventType;
        if (data['event'] == GeofenceEvent.enter.toString()) {
          eventType = "enter";
        } else if (data['event'] == GeofenceEvent.exit.toString()) {
          eventType = "exit";
        } else {
          eventType = "dwell";
        }

        String geofenceId = data['geofences'].first;

        //String url = 'http://10.0.2.2:5000/events/';
        String url = '$currentServer/events/';
        var response = await http.post(url, body: {
          'event': eventType,
          'time': timeStamp.toString(),
          'geofence': geofenceId
        });
        print(response.body);
      } else {
        // write to file
        print("no internet");
        writeEventLog(dataString, timeStamp);
      }
    } catch (e) {
      //throw e;
    }
  }

  Future<void> sendLogFileToServer() async {
    try {
      // read, send, delete contents
      String contents = await readLogFile();
      if (contents != "") {
        List data = json.decode(contents);
        String url = '$currentServer/events/';
        String eventType;
        String geofenceId;
        var response;
        for (Map<String, dynamic> log in data) {
          if (log['event'] == GeofenceEvent.enter.toString()) {
            eventType = "enter";
          } else if (log['event'] == GeofenceEvent.exit.toString()) {
            eventType = "exit";
          } else {
            eventType = "dwell";
          }

          geofenceId = log['geofences'].first;
          response = await http.post(url, body: {
            'event': eventType,
            'time': log['time'],
            'geofence': geofenceId
          });
        }
        if (response.statusCode == 200) {
          final file = await _localFile;
          return file.writeAsString("");
        }
      }
    } catch (e) {
      print(e.toString());
    }
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/eventLog.txt');
  }

  Future<File> writeEventLog(String dataString, DateTime time) async {
    try {
      final file = await _localFile;
      String logFileContent = await readLogFile();
      print("made it here, after reading log file");
      Map<String, dynamic> data = json.decode(dataString);

      data['time'] = time.toString();
      String newString;

      if (logFileContent == "") {
        newString = "[${json.encode(data)}]";

        print(newString);
      } else {
        List logFileJson = json.decode(logFileContent);
        logFileJson.add(data);
        newString = json.encode(logFileJson);
        print(newString);
      }
      return file.writeAsString(newString, mode: FileMode.write);
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  Future<String> readLogFile() async {
    try {
      final file = await _localFile;

      // Read the file.
      String contents = await file.readAsString();

      print(contents);

      return contents;
    } catch (e) {
      // If encountering an error, return 0.

      print("inside catch statement of readlog file: ${e.toString()}");
      return "";
    }
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    print('Initializing...');
    await GeofencingManager.initialize();
    print('Initialization done');
  }

  static void callback(List<String> ids, Location l, GeofenceEvent e) async {
    print('Fences: $ids Location $l Event: $e');
    final SendPort send =
        IsolateNameServer.lookupPortByName('geofencing_send_port');

    Map<String, dynamic> map = {
      "event": e.toString(),
      "geofences": ids,
      "location": l.toString(),
    };

    String data = json.encode(map);
    send?.send(data);
  }

  void registerHandler() {
    GeofencingManager.registerGeofence(
            GeofenceRegion(dropdownValue.id.toString(), dropdownValue.lat,
                dropdownValue.lng, dropdownValue.radius * 1.0, triggers,
                androidSettings: androidSettings),
            callback)
        .then((_) {
      GeofencingManager.getRegisteredGeofenceIds().then((value) {
        setState(() {
          registeredGeofences = value;
        });
      });
    });
  }

  void handleUnregister() {
    GeofencingManager.removeGeofenceById(dropdownValue.id.toString()).then((_) {
      GeofencingManager.getRegisteredGeofenceIds().then((value) {
        setState(() {
          registeredGeofences = value;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
          // Define the default brightness and colors.
          brightness: Brightness.dark,
          primaryColor: Colors.lightBlue[800],
          accentColor: Colors.cyan[600],

          // Define the default font family.
          fontFamily: 'Georgia',

          // Define the default TextTheme. Use this to specify the default
          // text styling for headlines, titles, bodies of text, and more.
          textTheme: TextTheme(
            headline1: TextStyle(fontSize: 72.0, fontWeight: FontWeight.bold),
            headline6: TextStyle(fontSize: 36.0, fontStyle: FontStyle.italic),
            bodyText2: TextStyle(fontSize: 14.0, fontFamily: 'Hind'),
          )),
      home: Scaffold(
          appBar: AppBar(
            title: const Text('Flutter Geofencing Example'),
            backgroundColor: Colors.black87,
            centerTitle: true,
          ),
          body: Container(
              //color: Colors.black87,
              padding: const EdgeInsets.all(10.0),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        "Last event: $geofenceState",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            color: Colors.white),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        "last record: $timeStamp",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 24),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      child: DropdownButton<Geofence>(
                        value: dropdownValue,
                        icon: Icon(Icons.arrow_downward),
                        iconSize: 24,
                        elevation: 16,
                        style: TextStyle(color: Colors.white),
                        underline: Container(
                          height: 2,
                          color: Colors.amber,
                        ),
                        onChanged: (Geofence newValue) {
                          setState(() {
                            dropdownValue = newValue;
                          });
                        },
                        items: availableGeofences
                            .map<DropdownMenuItem<Geofence>>((Geofence value) {
                          return DropdownMenuItem<Geofence>(
                            value: value,
                            child: Text(value.name),
                          );
                        }).toList(),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          child: RaisedButton(
                              child: const Text('Unregister',
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold)),
                              color: Colors.amber,
                              onPressed: () {
                                handleUnregister();
                              }),
                          padding: const EdgeInsets.only(right: 16),
                        ),
                        RaisedButton(
                          child: const Text(
                            'Register',
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold),
                          ),
                          color: Colors.amber,
                          onPressed: () {
                            registerHandler();
                          },
                        ),
                      ],
                    ),
                    Text('Registered Geofences: $registeredGeofences'),
                    FlatButton(
                        onPressed: () {
                          readLogFile();
                        },
                        child: Text("read file"))
                  ]))),
    );
  }
}
