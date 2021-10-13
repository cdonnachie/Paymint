import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

class BackupView extends StatefulWidget {
  @override
  _BackupViewState createState() => _BackupViewState();
}

class _BackupViewState extends State<BackupView> {
  _getAddresses() async {
    final wallet = await Hive.openBox('wallet');
    final addressArray = wallet.get('receivingAddresses');
    final publicKeyArray = wallet.get('receivingPublicKeys');
    final privateKeyArray = wallet.get('receivingPrivatekeys');

    final newAddressArray = [];
    addressArray.forEach((_address) => newAddressArray.add(_address));

    final newPublicKeyArray = [];
    publicKeyArray.forEach((_publicKey) => newPublicKeyArray.add(_publicKey));

    final newPrivateKeyArray = [];
    privateKeyArray
        .forEach((_privateKey) => newPrivateKeyArray.add(_privateKey));

    return addressArray;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Color(0xff121212),
          leading: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: Colors.cyanAccent,
              ),
              onPressed: () => Navigator.pop(context)),
          title: Text(
            'Your private key',
            style: GoogleFonts.rubik(color: Colors.white),
          ),
        ),
        backgroundColor: Color(0xff121212),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(
            'Write this private key down on some sort of secure physical medium that you will not eaily lose. It will allow you to restore your wallet in case you lose your phone or it\'s memory gets wiped unexpectedly.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        body: Padding(
          padding: EdgeInsets.all(16),
          child: FutureBuilder(
            future: _getAddresses(),
            builder: (BuildContext context, AsyncSnapshot snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return ListView.builder(
                    itemCount: snapshot.data.length,
                    itemBuilder: (BuildContext context, int index) {
                      final i = index + 1;
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            '$i: ' + snapshot.data[index],
                            textScaleFactor: 1.3,
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    });
              } else {
                return Center(child: CircularProgressIndicator());
              }
            },
          ),
        ),
      ),
    );
  }
}
