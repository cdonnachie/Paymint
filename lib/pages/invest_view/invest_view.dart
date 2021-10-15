import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ravencointlite/services/ravencoinlite_service.dart';
import 'package:ravencointlite/services/globals.dart';
import 'package:flutter_inner_drawer/inner_drawer.dart';
import 'package:provider/provider.dart';
import 'package:ravencointlite/services/utils/currency_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:ravencointlite/services/services.dart';
import 'package:url_launcher/url_launcher.dart';

class InvestView extends StatefulWidget {
  @override
  _InvestViewState createState() => _InvestViewState();
}

class _InvestViewState extends State<InvestView> with TickerProviderStateMixin {
  AnimationController _animationController;

  final GlobalKey<InnerDrawerState> _drawerKey = GlobalKey<InnerDrawerState>();

  final List<String> countries = countryList;
  final List<String> countriesDuplicate = [];
  TextEditingController searchEditingController = TextEditingController();

  Future<String> fetchCountry() async {
    return await CurrencyUtilities.fetchBankingCountry();
  }

  void _toggleRightDrawer() {
    _drawerKey.currentState.toggle(direction: InnerDrawerDirection.end);
  }

  void filterSearchResults(String query) {
    List<String> dummySearchList = [];
    dummySearchList.addAll(countriesDuplicate);
    if (query.isNotEmpty) {
      List<String> dummyListData = [];
      dummySearchList.forEach((String item) {
        if (item.toLowerCase().contains(query.toLowerCase())) {
          dummyListData.add(item);
        }
      });
      setState(() {
        countries.clear();
        countries.addAll(dummyListData);
      });
      return;
    } else {
      setState(() {
        countries.clear();
        countries.addAll(countriesDuplicate);
      });
    }
  }

  buildListTilesForExbitron() {
    ListTile exbitronTile = ListTile(
      leading: Stack(
        alignment: Alignment.center,
        children: [
          //CircleAvatar(backgroundColor: Colors.black),
          Image.asset(
            'assets/images/exbitron.png',
            height: 44,
          )
        ],
      ),
      title: Text(
        'Exbitron',
        style: TextStyle(color: Colors.white),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.lightBlue[600],
      ),
      onTap: () async {
        try {
          if (await canLaunch('https://exbitron.com/trading/rvlusdt')) {
            await launch('https://exbitron.com/trading/rvlusdt');
          } else {
            showModal(
              context: context,
              configuration: FadeScaleTransitionConfiguration(),
              builder: (context) =>
                  showErrorDialog(context, "Unable to open URL."),
            );
          }
        } catch (e) {
          showModal(
            context: context,
            configuration: FadeScaleTransitionConfiguration(),
            builder: (context) => showErrorDialog(context, e.toString()),
          );
        }
      },
    );

    return [exbitronTile];
  }

  buildListTilesForTradeOgre() {
    ListTile tradeOgreTile = ListTile(
      leading: Stack(
        alignment: Alignment.topCenter,
        children: [
          //CircleAvatar(backgroundColor: Colors.white),
          Image.asset(
            'assets/images/tradeogre.png',
            //height: 512,
          )
        ],
      ),
      title: Text(
        'Trade Ogre',
        style: TextStyle(color: Colors.white),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.lightBlue[600],
      ),
      onTap: () async {
        try {
          if (await canLaunch('https://tradeogre.com/exchange/BTC-RVL')) {
            await launch('https://tradeogre.com/exchange/BTC-RVL');
          } else {
            showModal(
              context: context,
              configuration: FadeScaleTransitionConfiguration(),
              builder: (context) =>
                  showErrorDialog(context, "Unable to open URL."),
            );
          }
        } catch (e) {
          showModal(
            context: context,
            configuration: FadeScaleTransitionConfiguration(),
            builder: (context) => showErrorDialog(context, e.toString()),
          );
        }
      },
    );

    return [tradeOgreTile];
  }

  @override
  void initState() {
    _animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _animationController.repeat(reverse: true);
    for (var i = 0; i < countryList.length; i++) {
      countriesDuplicate.add(countryList[i]);
    }

    super.initState();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final RavencoinLiteService ravencoinLiteService =
        Provider.of<RavencoinLiteService>(context);

    return InnerDrawer(
      swipeChild: true,
      key: _drawerKey,
      onTapClose: true,
      swipe: true,
      offset: IDOffset.horizontal(1),
      scale: IDOffset.horizontal(1),
      rightAnimationType: InnerDrawerAnimation.quadratic,
      colorTransitionChild: Colors.lightBlue[600],

      // Payment method view
      rightChild: SafeArea(
        child: Scaffold(
          backgroundColor: Color(0xff121212),
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: Colors.lightBlue[600],
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Exchanges',
              style: GoogleFonts.rubik(color: Colors.white),
            ),
          ),
          body: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Buy/Sell Ravencoin Lite',
                  textScaleFactor: 1.25,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              Expanded(
                child: ListView(
                  children: buildListTilesForExbitron(),
                ),
              ),
              Expanded(
                flex: 4,
                child: ListView(
                  children: buildListTilesForTradeOgre(),
                ),
              ),
            ],
          ),
        ),
      ),

      // Main invest view
      scaffold: SafeArea(
        child: Scaffold(
          backgroundColor: Color(0xff121212),
          bottomNavigationBar: Container(
            height: 100,
          ),
          body: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Center(
                child: Container(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Invest',
                    textScaleFactor: 1.5,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Center(
                      child: ScaleTransition(
                        scale: Tween(begin: 0.75, end: 1.0)
                            .animate(CurvedAnimation(
                          parent: _animationController,
                          curve: Curves.elasticOut,
                        )),
                        child: GestureDetector(
                          onTap: () => _toggleRightDrawer(),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(70),
                                child: Container(
                                  height: 70,
                                  width: 70,
                                  color: Colors.white,
                                ),
                              ),
                              Image.asset(
                                'assets/images/rvl.png',
                                height: 70.0,
                                width: 70.0,
                                color: Colors.blueAccent,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 32),
                    FutureBuilder(
                      future: ravencoinLiteService.currency,
                      builder: (BuildContext context,
                          AsyncSnapshot<String> currencyData) {
                        if (currencyData.connectionState ==
                            ConnectionState.done) {
                          return FutureBuilder(
                            future: ravencoinLiteService.ravencoinLitePrice,
                            builder: (BuildContext context,
                                AsyncSnapshot<dynamic> priceData) {
                              if (priceData.connectionState ==
                                  ConnectionState.done) {
                                if (priceData.hasError ||
                                    priceData.data == null) {
                                  // Build price load error widget below later
                                  return Text(
                                    'Is your internet connection active?',
                                    style: TextStyle(color: Colors.white),
                                  );
                                }

                                String fmf = priceData.data;
                                //FlutterMoneyFormatter(amount: priceData.data);
                                final String displayPriceNonSymbol = fmf;
                                // Triggers code below when no errors are found :D
                                return Text(
                                  currencyMap[currencyData.data] +
                                      displayPriceNonSymbol,
                                  style: TextStyle(color: Colors.white),
                                  textScaleFactor: 1.5,
                                );
                              } else {
                                return buildLoadingWidget();
                              }
                            },
                          );
                        } else {
                          return buildLoadingWidget();
                        }
                      },
                    ),
                    SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                      child: Text(
                        '(Tap on the Ravencoin Lite logo to select an Exchange)',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Center buildLoadingWidget() {
  return Center(
    child: CircularProgressIndicator(),
  );
}

AlertDialog showErrorDialog(BuildContext context, String error) {
  return AlertDialog(
    title: Text(
      'Error',
      style: TextStyle(color: Colors.white),
    ),
    content: Text(
      error,
      style: TextStyle(color: Colors.white),
    ),
    actions: [
      ElevatedButton(onPressed: () => Navigator.pop(context), child: Text('OK'))
    ],
  );
}
