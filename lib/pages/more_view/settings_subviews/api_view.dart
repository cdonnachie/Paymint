import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:ravencointlite/services/services.dart';
import 'package:flutter/cupertino.dart';

class APIView extends StatefulWidget {
  @override
  _APIViewState createState() => _APIViewState();
}

class _APIViewState extends State<APIView> {
  TextEditingController textController = new TextEditingController();

  @override
  Widget build(BuildContext context) {
    final RavencoinLiteService ravencoinLiteService =
        Provider.of<RavencoinLiteService>(context);

    return Scaffold(
      backgroundColor: Color(0xff121212),
      bottomNavigationBar: Container(
        height: 100,
        child: Center(
          child: CupertinoButton.filled(
            onPressed: () async {
              final wallet = await Hive.openBox('wallet');

              if (textController.text.isEmpty ||
                  textController.text.trim() == '') {
                await wallet.put('api_url', 'https://api.ravencoinlite.org');
              } else {
                await wallet.put('api_url', textController.text);
              }
            },
            child: Text('Save changes'),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ListView(
          children: <Widget>[
            Text(
              'Input the publicly accessible url of your API server below. Leaving it blank will default to Ravencoin Lite servers',
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 24),
            FutureBuilder(
              future: ravencoinLiteService.getAPIUrl(),
              builder: (BuildContext context, AsyncSnapshot<String> apiUrl) {
                if (apiUrl.connectionState == ConnectionState.done) {
                  return TextField(
                    controller: textController,
                    autofocus: true,
                    showCursor: true,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      labelText: 'Server URL',
                      hintText: apiUrl.data,
                    ),
                  );
                } else {
                  return Text('Loading...');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
