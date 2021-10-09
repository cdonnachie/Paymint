import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:ravencointlite/services/ravencoinlite_service.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;
import 'package:local_auth/local_auth.dart';

class GeneralView extends StatefulWidget {
  @override
  _GeneralViewState createState() => _GeneralViewState();
}

class _GeneralViewState extends State<GeneralView> {
  @override
  Widget build(BuildContext context) {
    final RavencoinLiteService ravencoinLiteService = Provider.of(context);

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
        body: ListView(
          children: [
            Center(
              child: Container(
                padding: EdgeInsets.all(16),
                child: Text(
                  'General Settings',
                  textScaleFactor: 1.5,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            SizedBox(height: 16),
            FutureBuilder(
              future: ravencoinLiteService.currency,
              builder: (BuildContext context, AsyncSnapshot<String> currency) {
                if (currency.connectionState == ConnectionState.done) {
                  return ListTile(
                    leading: Text(
                      'Currency:',
                      style: TextStyle(color: Colors.white),
                    ),
                    trailing: Text(
                      currency.data,
                      style: TextStyle(color: Colors.cyanAccent),
                    ),
                    onTap: () {
                      Navigator.pushNamed(context, '/changecurrency');
                    },
                  );
                } else {
                  return ListTile(
                    leading: Text(
                      'Currency:',
                      style: TextStyle(color: Colors.white),
                    ),
                    trailing: Text(
                      'Loading',
                      style: TextStyle(color: Colors.cyanAccent),
                    ),
                  );
                }
              },
            ),
            FutureBuilder(
              future: ravencoinLiteService.useBiometrics,
              builder: (BuildContext context, AsyncSnapshot<bool> useBio) {
                if (useBio.connectionState == ConnectionState.done) {
                  return ListTile(
                    leading: Text(
                      _buildUseBioText(),
                      style: TextStyle(color: Colors.white),
                    ),
                    trailing: Icon(
                      buildBioAuthIcon(),
                      color: buildFingerPrintColor(useBio.data),
                    ),
                    onTap: () async {
                      // Insert logic to first authenticate biometrics before enabling
                      if (useBio.data) {
                        await ravencoinLiteService.updateBiometricsUsage();
                      } else {
                        final LocalAuthentication localAuthentication =
                            LocalAuthentication();

                        bool canCheckBiometrics =
                            await localAuthentication.canCheckBiometrics;

                        if (canCheckBiometrics) {
                          List<BiometricType> availableSystems =
                              await localAuthentication
                                  .getAvailableBiometrics();

                          if (Platform.isIOS) {
                            if (availableSystems.contains(BiometricType.face)) {
                              // Write iOS specific code when required
                            } else if (availableSystems
                                .contains(BiometricType.fingerprint)) {
                              // Write iOS specific code when required
                            }
                          } else if (Platform.isAndroid) {
                            if (availableSystems
                                .contains(BiometricType.fingerprint)) {
                              bool didAuthenticate = await localAuthentication
                                  .authenticateWithBiometrics(
                                localizedReason:
                                    'Please authenticate to enable biometric lock',
                                stickyAuth: true,
                              );
                              if (didAuthenticate) {
                                await ravencoinLiteService
                                    .updateBiometricsUsage();
                              }
                            }
                          }
                        }
                      }
                      // await ravencoinLiteService.updateBiometricsUsage();
                    },
                  );
                } else {
                  return ListTile(
                    leading: Text(
                      _buildUseBioText(),
                      style: TextStyle(color: Colors.white),
                    ),
                    trailing: Icon(
                      Icons.fingerprint,
                      color: Colors.grey,
                    ),
                  );
                }
              },
            ),
            ListTile(
              title:
                  Text('Refresh Wallet', style: TextStyle(color: Colors.white)),
              trailing: Icon(Icons.refresh, color: Colors.cyanAccent),
              onTap: () async {
                showModal(
                  context: context,
                  configuration: FadeScaleTransitionConfiguration(
                      barrierDismissible: false),
                  builder: (BuildContext context) {
                    return showLoadingDialog(context);
                  },
                );
                await ravencoinLiteService.refreshWalletData();
                Navigator.pop(context);
              },
            )
          ],
        ),
      ),
    );
  }
}

// General View helper functions

String _buildUseBioText() {
  if (Platform.isAndroid) {
    return 'Enable fingerprint lock';
  } else {
    return 'Enable FaceID/TouchID';
  }
}

Color buildFingerPrintColor(bool status) {
  if (status == true) {
    return Colors.cyanAccent;
  } else {
    return Colors.grey;
  }
}

IconData buildBioAuthIcon() {
  if (Platform.isAndroid) {
    return Icons.fingerprint;
  } else {
    return Icons.tag_faces;
  }
}

AlertDialog showLoadingDialog(BuildContext context) {
  return AlertDialog(
    backgroundColor: Colors.black,
    title: Row(
      children: [
        CircularProgressIndicator(),
        SizedBox(width: 12),
        Text('Refreshing wallet', style: TextStyle(color: Colors.white)),
      ],
    ),
  );
}
