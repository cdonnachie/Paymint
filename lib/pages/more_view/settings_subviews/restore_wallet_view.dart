import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:provider/provider.dart';
import 'package:ravencointlite/services/services.dart';
import 'package:flutter/cupertino.dart';

class RestoreWalletView extends StatefulWidget {
  @override
  _RestoreWalletViewState createState() => _RestoreWalletViewState();
}

class _RestoreWalletViewState extends State<RestoreWalletView> {
  TextEditingController textController = new TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xff121212),
      bottomNavigationBar: Container(
        height: 100,
        child: Center(
          child: CupertinoButton.filled(
            onPressed: () async {
              final rvlService =
                  Provider.of<RavencoinLiteService>(context, listen: false);
              if (await rvlService
                      .validateAddress(textController.text.trim()) ==
                  false) {
                showModal(
                  context: context,
                  configuration: FadeScaleTransitionConfiguration(),
                  builder: (BuildContext context) {
                    return InvalidInputDialog();
                  },
                );
              } else {
                final rvlService =
                    Provider.of<RavencoinLiteService>(context, listen: false);
                showModal(
                  context: context,
                  configuration: FadeScaleTransitionConfiguration(
                      barrierDismissible: false),
                  builder: (BuildContext context) {
                    return WaitDialog();
                  },
                );
                await rvlService.recoverWalletFromWIF(textController.text);
                await rvlService.refreshWalletData();
                Navigator.pop(context);
                showModal(
                  context: context,
                  configuration: FadeScaleTransitionConfiguration(),
                  builder: (BuildContext context) {
                    return RecoveryCompleteDialog();
                  },
                );
              }
            },
            child: Text('Recover wallet'),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ListView(
          children: <Widget>[
            Text(
              'Input your backup\'s private key.',
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 24),
            TextField(
              controller: textController,
              autofocus: true,
              showCursor: true,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                labelText: 'WIF',
              ),
            )
          ],
        ),
      ),
    );
  }
}

// Dialog Widgets

class InvalidInputDialog extends StatelessWidget {
  const InvalidInputDialog({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Invalid input'),
      content: Text('Please input a valid WIF and try again'),
      actions: <Widget>[
        ElevatedButton(
          child: Text('OK'),
          onPressed: () {
            Navigator.pop(context);
          },
        )
      ],
    );
  }
}

class RecoveryCompleteDialog extends StatelessWidget {
  const RecoveryCompleteDialog({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black,
      title: Text('Recovery complete', style: TextStyle(color: Colors.white)),
      content: Text(
        'Wallet recovery has completed. Hop in support if something doesn\'t seem right',
        style: TextStyle(color: Colors.white),
      ),
      actions: <Widget>[
        ElevatedButton(
          child: Text('OK'),
          onPressed: () {
            Navigator.pop(context);
          },
        )
      ],
    );
  }
}

class WaitDialog extends StatelessWidget {
  const WaitDialog({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black,
      title: Row(
        children: <Widget>[
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Text('Please do not exit', style: TextStyle(color: Colors.white)),
        ],
      ),
      content: Text(
        "We're attempting to recover your wallet and it may take a few minutes. Please do not exit the app or leave this screen",
        style: TextStyle(color: Colors.white),
      ),
    );
  }
}
