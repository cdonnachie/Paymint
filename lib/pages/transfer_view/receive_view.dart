import 'package:flutter/material.dart';
import 'package:ravencointlite/services/ravencoinlite_service.dart';
import 'package:provider/provider.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:flutter/services.dart';
import 'package:toast/toast.dart';
import 'package:share/share.dart';

class ReceiveView extends StatefulWidget {
  ReceiveView({Key key}) : super(key: key);

  @override
  _ReceiveViewState createState() => _ReceiveViewState();
}

class _ReceiveViewState extends State<ReceiveView> {
  @override
  Widget build(BuildContext context) {
    final RavencoinLiteService ravencoinLiteService =
        Provider.of<RavencoinLiteService>(context);
    bool roundQr = true;

    return SafeArea(
      child: Scaffold(
        backgroundColor: Color(0xff121212),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Color(0xff81D4FA),
          child: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: EdgeInsets.all(12),
              child: Text(
                'Receive Ravencoin Lite',
                textScaleFactor: 1.5,
                style: TextStyle(color: Colors.white),
              ),
            ),
            FutureBuilder(
              future: ravencoinLiteService.currentReceivingAddress,
              builder:
                  (BuildContext context, AsyncSnapshot<String> currentAddress) {
                if (currentAddress.connectionState == ConnectionState.done) {
                  return Expanded(
                    child: Center(
                      child: PrettyQr(
                        data: currentAddress.data,
                        roundEdges: roundQr,
                        elementColor: Colors.white,
                        typeNumber: 4,
                        size: 250,
                      ),
                    ),
                  );
                } else {
                  return Container(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()));
                }
              },
            ),
            FutureBuilder(
              future: ravencoinLiteService.currentReceivingAddress,
              builder: (BuildContext context, AsyncSnapshot<String> address) {
                if (address.connectionState == ConnectionState.done) {
                  return ListTile(
                    title: Text(
                      'Address:',
                      style: TextStyle(color: Colors.white),
                    ),
                    trailing: Text(
                      condenseAdress(address.data),
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {},
                  );
                } else {
                  return ListTile();
                }
              },
            ),
            FutureBuilder(
              future: ravencoinLiteService.currentReceivingAddress,
              builder: (BuildContext context, AsyncSnapshot snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return ListTile(
                    title: Text(
                      'Copy address to clipboard',
                      style: TextStyle(color: Colors.lightBlueAccent.shade700),
                    ),
                    onTap: () {
                      Clipboard.setData(new ClipboardData(text: snapshot.data));
                      Toast.show(
                        'Address copied to clipboard',
                        context,
                        duration: Toast.LENGTH_LONG,
                        gravity: Toast.BOTTOM,
                      );
                    },
                  );
                } else {
                  return ListTile(
                    title: Text(
                      'Copy address to clipboard',
                      style: TextStyle(color: Colors.lightBlueAccent.shade700),
                    ),
                  );
                }
              },
            ),
            FutureBuilder(
              future: ravencoinLiteService.currentReceivingAddress,
              builder: (BuildContext context, AsyncSnapshot snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return ListTile(
                    title: Text(
                      'Share address',
                      style: TextStyle(color: Colors.lightBlueAccent.shade700),
                    ),
                    onTap: () {
                      Share.share(snapshot.data);
                    },
                  );
                } else {
                  return ListTile(
                    title: Text(
                      'Share address',
                      style: TextStyle(color: Colors.lightBlueAccent.shade700),
                    ),
                  );
                }
              },
            ),
            ListTile(
              title: Text(
                'View addresses',
                style: TextStyle(color: Colors.lightBlueAccent.shade700),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: Colors.lightBlueAccent.shade700,
              ),
              onTap: () {
                Navigator.pushNamed(context, '/addressbook');
              },
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// Receive View helper functions

String condenseAdress(String address) {
  return address.substring(0, 8) +
      '...' +
      address.substring(address.length - 8);
}
