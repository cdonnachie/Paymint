import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ravencointlite/services/services.dart';
import 'package:animations/animations.dart';

class ChangeCurrencyView extends StatefulWidget {
  @override
  _ChangeCurrencyViewState createState() => _ChangeCurrencyViewState();
}

class _ChangeCurrencyViewState extends State<ChangeCurrencyView> {
  final currencyList = [
    "AUD",
    "CAD",
    "CHF",
    "CNY",
    "EUR",
    "GBP",
    "HKD",
    "INR",
    "JPY",
    "KRW",
    "PHP",
    "SGD",
    "TRY",
    "USD",
    "XAU",
  ];

  @override
  Widget build(BuildContext context) {
    final RavencoinLiteService rvlService =
        Provider.of<RavencoinLiteService>(context);
    return FutureBuilder(
      future: rvlService.currency,
      builder: (BuildContext context, AsyncSnapshot<String> currency) {
        if (currency.connectionState == ConnectionState.done) {
          return _buildChangeCurrencyView(context, currency);
        } else {
          return Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  _buildChangeCurrencyView(
      BuildContext context, AsyncSnapshot<String> currency) {
    return Scaffold(
      body: ListView.builder(
        itemCount: currencyList.length,
        itemBuilder: (BuildContext context, int index) {
          return _buildCurrencyListTile(index, currency.data);
        },
      ),
    );
  }

  _buildCurrencyListTile(int index, String selectedCurrency) {
    if (currencyList[index] == selectedCurrency) {
      final String symbol = currencyMap[currencyList[index]];
      return Container(
        color: Color(0xff121212),
        child: ListTile(
          title: Text(selectedCurrency + ' ~ $symbol',
              style: TextStyle(color: Colors.white)),
          trailing: Icon(
            Icons.check,
            color: Colors.lightBlueAccent.shade700,
          ),
          onTap: () {},
        ),
      );
    } else {
      final String symbol = currencyMap[currencyList[index]];
      return Container(
        color: Color(0xff121212),
        child: ListTile(
          title: Text(currencyList[index] + ' ~ $symbol',
              style: TextStyle(color: Colors.white)),
          onTap: () async {
            showModal(
              context: context,
              configuration:
                  FadeScaleTransitionConfiguration(barrierDismissible: false),
              builder: (BuildContext context) {
                return _currencySwitchDialog(currencyList[index]);
              },
            );
            final RavencoinLiteService rvlService =
                Provider.of<RavencoinLiteService>(context);
            await rvlService.refreshWalletData();
            Navigator.pop(context);
          },
        ),
      );
    }
  }

  _currencySwitchDialog(String newCurrency) {
    return AlertDialog(
      backgroundColor: Colors.black,
      title: Row(
        children: <Widget>[
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Text(
            'Switching currency...',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
      content: Text(
        "Please wait while we refresh wallet data in $newCurrency",
        style: TextStyle(color: Colors.white),
      ),
    );
  }
}
