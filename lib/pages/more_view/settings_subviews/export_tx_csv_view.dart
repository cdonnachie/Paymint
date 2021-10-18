import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:ravencointlite/models/models.dart';
import 'package:ravencointlite/services/services.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ExportTransactionCsvView extends StatefulWidget {
  @override
  _ExportTransactionCsvViewState createState() =>
      _ExportTransactionCsvViewState();
}

class _ExportTransactionCsvViewState extends State<ExportTransactionCsvView> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    final RavencoinLiteService ravencoinLiteService =
        Provider.of<RavencoinLiteService>(context);

    return ScaffoldMessenger(
        key: _scaffoldMessengerKey,
        child: Scaffold(
          backgroundColor: Color(0xff121212),
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back,
                  color: Colors.lightBlueAccent.shade700),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Export transaction data to CSV',
              style: GoogleFonts.rubik(color: Colors.white),
            ),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'The format is simple. Each line represents the data for a single transaction and has 9 values:\n\n1) Transaction ID\n2) Transaction type\n3) Transaction timestamp\n4) Transaction amount in satoshis\n5) Worth when sent/received\n6) Current worth\n7) Fee paid\n8) # of Inputs\n9) # of Outputs',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              Expanded(
                child: Center(
                  child: FutureBuilder(
                    future: ravencoinLiteService.transactionData,
                    builder: (BuildContext context,
                        AsyncSnapshot<TransactionData> snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        return MaterialButton(
                          onPressed: () async {
                            await txDataTo2dArray(snapshot.data);
                          },
                          color: Colors.amber,
                          textColor: Color(0xff121212),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18.0)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.save, color: Color(0xff121212)),
                              SizedBox(width: 8),
                              Text('Save locally to device')
                            ],
                          ),
                        );
                      } else {
                        return Container();
                      }
                    },
                  ),
                ),
              )
            ],
          ),
        ));
  }

  txDataTo2dArray(TransactionData txData) async {
    if (txData.txChunks.length == 0) {
      _scaffoldMessengerKey.currentState.showSnackBar(SnackBar(
        backgroundColor: Colors.red,
        content: Text('No transaction data to export',
            style: TextStyle(color: Colors.white)),
      ));

      return 0;
    }

    // Output Name  --  Output txid  --  Output block status  --
    final List<List<String>> formattedData = [];

    for (var i = 0; i < txData.txChunks.length; i++) {
      final txChunk = txData.txChunks[i];

      for (var i = 0; i < txChunk.transactions.length; i++) {
        final List<String> txDataList = [];
        final tx = txChunk.transactions[i];

        txDataList.add(tx.txid.toString());
        txDataList.add(tx.txType.toString());
        txDataList.add(tx.timestamp.toString());
        txDataList.add(tx.amount.toString());
        txDataList.add(tx.worthNow.toString());
        txDataList.add(tx.fees.toString());
        txDataList.add(tx.inputSize.toString());
        txDataList.add(tx.outputSize.toString());

        formattedData.add(txDataList);
      }
    }

    String csv = ListToCsvConverter().convert(formattedData);
    print(csv);

    final directory = await getExternalStorageDirectory();
    print(directory.path);
    final File file = File('${directory.path}/transactionData.csv');
    await file.writeAsString(csv);

    _scaffoldMessengerKey.currentState.showSnackBar(SnackBar(
      backgroundColor: Colors.green,
      content: Text('Transaction data successfully exported to CSV',
          style: TextStyle(color: Colors.white)),
    ));

    return 1;
  }
}
