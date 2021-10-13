import 'dart:typed_data';
import 'package:currency_formatter/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ravencointlite/models/models.dart';
import 'package:hive/hive.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bitcoin_flutter/bitcoin_flutter.dart';
import 'package:bip32/bip32.dart' as bip32;
import 'package:bip39/bip39.dart' as bip39;
import 'package:ravencointlite/services/globals.dart';
import 'package:ravencointlite/services/utils/currency_utils.dart';
import 'package:hex/hex.dart';

class RavencoinLiteService extends ChangeNotifier {
  /// Holds final balances, all utxos under control
  Future<UtxoData> _utxoData;
  Future<UtxoData> get utxoData => _utxoData;

  /// Holds wallet transaction data
  Future<TransactionData> _transactionData;
  Future<TransactionData> get transactionData => _transactionData;

  /// Holds all receiving addresses
  List<ReceivingAddresses> _receivingAddresses;
  List<ReceivingAddresses> get receivingAddresses => _receivingAddresses;

  // Holds charting information
  Future<ChartModel> _chartData;
  Future<ChartModel> get chartData => _chartData ??= getChartData();

  /// Holds all outputs for wallet, used for displaying utxos in app security view
  List<UtxoObject> _outputsList = [];
  List<UtxoObject> get allOutputs => _outputsList;

  // Hold the current price of Ravencoin Lite in the currency specified in parameter below
  Future<dynamic> _ravencoinLitePrice;
  Future<dynamic> get ravencoinLitePrice =>
      _ravencoinLitePrice ??= getRavencoinLitePrice();

  Future<FeeObject> _feeObject;
  Future<FeeObject> get fees => _feeObject ??= getFees();

  Future<String> _marketInfo;
  Future<String> get marketInfo => _marketInfo ??= getMarketInfo();

  /// Holds preferred fiat currency
  Future<String> _currency;
  Future<String> get currency =>
      _currency ??= CurrencyUtilities.fetchPreferredCurrency();

  /// Holds updated receiving address
  Future<String> _currentReceivingAddress;
  Future<String> get currentReceivingAddress => _currentReceivingAddress;

  Future<bool> _useBiomterics;
  Future<bool> get useBiometrics => _useBiomterics;

  NetworkType ravencoinLiteNetwork = new NetworkType(
      messagePrefix: '\x19Raven Signed Message:\n',
      bip32: new Bip32Type(public: 0x0488b21e, private: 0x0488ade4),
      bech32: "raven",
      pubKeyHash: 0x3C,
      scriptHash: 0x7A,
      wif: 0x80);

  RavencoinLiteService() {
    _currency = CurrencyUtilities.fetchPreferredCurrency();

    _initializeRavencoinLiteWallet().whenComplete(() {
      _utxoData = _fetchUtxoData();
      _transactionData = _fetchTransactionData();
    }).whenComplete(() => checkReceivingAddressForTransactions());
  }

  /// Initializes the user's wallet and sets class getters. Will create a wallet if one does not
  /// already exist.
  Future<void> _initializeRavencoinLiteWallet() async {
    final wallet = await Hive.openBox('wallet');
    if (wallet.isEmpty) {
      // Triggers for new users automatically. Generates new wallet
      await _generateNewWallet(wallet);
    } else {
      // Wallet alreiady exists, triggers for a returning user
      this._currentReceivingAddress = _getCurrentAddress();
      this._useBiomterics = Future(
        () async => await wallet.get('use_biometrics'),
      );
    }
  }

  /// Generates initial wallet values such as mnemonic, chain (receive/change) arrays and indexes.
  Future<void> _generateNewWallet(Box<dynamic> wallet) async {
    final secureStore = new FlutterSecureStorage();
    // Set relevant indexes
    await wallet.put('receivingIndex', 0);
    await wallet.put('use_biometrics', false);
    await wallet.put('blocked_tx_hashes', [
      "0xdefault"
    ]); // A list of transaction hashes to represent frozen utxos in wallet
    // Generate and add addresses to relevant arrays
    ECPair keys = ECPair.makeRandom(network: ravencoinLiteNetwork);
    final initialReceivingAddress = await generateAddress(keys);
    await secureStore.write(
        key: 'receivingAddress', value: initialReceivingAddress);
    await secureStore.write(
        key: 'receivingAddressPubkey', value: HEX.encode(keys.publicKey));
    await secureStore.write(
        key: 'receivingAddressWif', value: HEX.encode(keys.privateKey));
    await addToAddressesArray(initialReceivingAddress,
        HEX.encode(keys.publicKey), HEX.encode(keys.privateKey));

    this._currentReceivingAddress = Future(() => initialReceivingAddress);
    this._useBiomterics = Future(
      () async => await wallet.get('use_biometrics'),
    );
  }

  /// Refreshes display data for the wallet
  refreshWalletData() async {
    final UtxoData newUtxoData = await _fetchUtxoData();
    final TransactionData newTxData = await _fetchTransactionData();
    final dynamic newRvlPrice = await getRavencoinLitePrice();
    final FeeObject feeObj = await getFees();
    final String marketInfo = await getMarketInfo();
    await checkReceivingAddressForTransactions();

    this._utxoData = Future(() => newUtxoData);
    this._transactionData = Future(() => newTxData);
    this._ravencoinLitePrice = Future(() => newRvlPrice);
    this._feeObject = Future(() => feeObj);
    this._marketInfo = Future(() => marketInfo);
    notifyListeners();
  }

  /// Generates a new internal or external chain address for the wallet using a BIP84 derivation path.
  /// [keys] - Random generated keys from network
  /// [chain] - Use 0 for receiving (external), 1 for change (internal). Should not be any other value!
  Future<String> generateAddress(ECPair keys) async {
    return P2PKH(
            data: new PaymentData(pubkey: keys.publicKey),
            network: ravencoinLiteNetwork)
        .data
        .address;
  }

  /// Increases the index for either the internal or external chain, depending on [chain].
  /// [chain] - Use 0 for receiving (external), 1 for change (internal). Should not be any other value!
  Future<void> incrementAddressIndex() async {
    final wallet = await Hive.openBox('wallet');
    final newIndex = wallet.get('receivingIndex') + 1;
    await wallet.put('receivingIndex', newIndex);
  }

  /// Adds [address] to the relevant receiving address array.
  /// [address] - Expects a legacy address
  Future<void> addToAddressesArray(
      String address, String publicKey, String privateKey) async {
    final wallet = await Hive.openBox('wallet');

    final addressArray = wallet.get('receivingAddresses');
    final publicKeyArray = wallet.get('receivingPublicKeys');
    final privateKeyArray = wallet.get('receivingPrivatekeys');
    if (addressArray == null) {
      await wallet.put('receivingAddresses', [address]);
      await wallet.put('receivingPublicKeys', [publicKey]);
      await wallet.put('receivingPrivatekeys', [privateKey]);
    } else {
      // Make a deep copy of the exisiting list
      final newAddressArray = [];
      addressArray.forEach((_address) => newAddressArray.add(_address));
      newAddressArray.add(address); // Add the address passed into the method
      await wallet.put('receivingAddresses', newAddressArray);

      final newPublicKeyArray = [];
      publicKeyArray.forEach((_publicKey) => newPublicKeyArray.add(_publicKey));
      newPublicKeyArray
          .add(publicKey); // Add the address passed into the method
      await wallet.put('receivingPublicKeys', newPublicKeyArray);

      final newPrivateKeyArray = [];
      privateKeyArray
          .forEach((_privateKey) => newPrivateKeyArray.add(_privateKey));
      newPrivateKeyArray
          .add(privateKey); // Add the address passed into the method
      await wallet.put('receivingPrivateKeys', newPrivateKeyArray);
    }
  }

  /// Returns the latest receiving/change (external/internal) address for the wallet depending on [chain]
  /// [chain] - Use 0 for receiving (external), 1 for change (internal). Should not be any other value!
  Future<String> _getCurrentAddress() async {
    final wallet = await Hive.openBox('wallet');
    final externalChainArray = await wallet.get('receivingAddresses');
    return externalChainArray.last;
  }

  void blockOutput(String txid) {
    for (var i = 0; i < allOutputs.length; i++) {
      if (allOutputs[i].txid == txid) {
        allOutputs[i].blocked = true;
        notifyListeners();
      }
    }
  }

  void unblockOutput(String txid) {
    for (var i = 0; i < allOutputs.length; i++) {
      if (allOutputs[i].txid == txid) {
        allOutputs[i].blocked = false;
        notifyListeners();
      }
    }
  }

  void renameOutput(String txid, String newName) {
    for (var i = 0; i < allOutputs.length; i++) {
      if (allOutputs[i].txid == txid) {
        allOutputs[i].txName = newName;
        notifyListeners();
      }
    }
  }

  /// Changes the biometrics auth setting used on the lockscreen as an alternative
  /// to the pattern lock
  updateBiometricsUsage() async {
    final wallet = await Hive.openBox('wallet');
    final bool useBio = await wallet.get('use_biometrics');

    if (useBio) {
      _useBiomterics = Future(() => false);
      await wallet.put('use_biometrics', false);
    } else {
      _useBiomterics = Future(() => true);
      await wallet.put('use_biometrics', true);
    }
    notifyListeners();
  }

  /// Switches preferred fiat currency for display and data fetching purposes
  changeCurrency(String newCurrency) async {
    final prefs = await Hive.openBox('prefs');
    await prefs.put('currency', newCurrency);
    this._currency = Future(() => newCurrency);
    notifyListeners();
  }

  /// Takes in a list of UtxoObjects and adds a name (dependent on object index within list)
  /// and checks for the txid associated with the utxo being blocked and marks it accordingly.
  /// Now also checks for output labeling.
  _sortOutputs(List<UtxoObject> utxos) async {
    final wallet = await Hive.openBox('wallet');
    final blockedHashArray = wallet.get('blocked_tx_hashes');
    final lst = [];
    blockedHashArray.forEach((hash) => lst.add(hash));
    final labels = await Hive.openBox('labels');

    this._outputsList = [];

    for (var i = 0; i < utxos.length; i++) {
      if (labels.get(utxos[i].txid) != null) {
        utxos[i].txName = labels.get(utxos[i].txid);
      } else {
        utxos[i].txName = 'Output #$i';
      }

      if (utxos[i].status.confirmed == false) {
        this._outputsList.add(utxos[i]);
      } else {
        if (lst.contains(utxos[i].txid)) {
          utxos[i].blocked = true;
          this._outputsList.add(utxos[i]);
        } else if (!lst.contains(utxos[i].txid)) {
          this._outputsList.add(utxos[i]);
        }
      }
    }
    notifyListeners();
  }

  /// The coinselection algorithm decides whether or not the user is eligible to make the transaction
  /// with [satoshiAmountToSend] and [selectedTxFee]. If so, it will call buildTrasaction() and return
  /// a map containing the tx hex along with other important information. If not, then it will return
  /// an integer (1 or 2)
  dynamic coinSelection(int satoshiAmountToSend, dynamic selectedTxFee,
      String _recipientAddress) async {
    final List<UtxoObject> availableOutputs = this.allOutputs;
    final List<UtxoObject> spendableOutputs = [];
    int spendableSatoshiValue = 0;

    // Build list of spendable outputs and totaling their satoshi amount
    for (var i = 0; i < availableOutputs.length; i++) {
      if (availableOutputs[i].blocked == false &&
          availableOutputs[i].status.confirmed == true) {
        spendableOutputs.add(availableOutputs[i]);
        spendableSatoshiValue += availableOutputs[i].value;
      }
    }

    // If the amount the user is trying to send is smaller than the amount that they have spendable,
    // then return 1, which indicates that they have an insufficient balance.
    if (spendableSatoshiValue < satoshiAmountToSend) {
      return 1;
      // If the amount the user wants to send is exactly equal to the amount they can spend, then return
      // 2, which indicates that they are not leaving enough over to pay the transaction fee
    } else if (spendableSatoshiValue == satoshiAmountToSend) {
      return 2;
    }
    // If neither of these statements pass, we assume that the user has a spendable balance greater
    // than the amount they're attempting to send. Note that this value still does not account for
    // the added transaction fee, which may require an extra input and will need to be checked for
    // later on.

    // Possible situation right here
    int satoshisBeingUsed = 0;
    int inputsBeingConsumed = 0;
    List<UtxoObject> utxoObjectsToUse = [];

    for (var i = 0; satoshisBeingUsed < satoshiAmountToSend; i++) {
      utxoObjectsToUse.add(spendableOutputs[i]);
      satoshisBeingUsed += spendableOutputs[i].value;
      inputsBeingConsumed += 1;
    }

    // numberOfOutputs' length must always be equal to that of recipientsArray and recipientsAmtArray
    List<String> recipientsArray = [_recipientAddress];
    List<int> recipientsAmtArray = [satoshiAmountToSend];

    // Assume 1 output, only for recipient and no change
    final feeForOneOutput =
        ((42 + 272 * inputsBeingConsumed + 128) / 4).ceil() *
            selectedTxFee.ceil();
    // Assume 2 outputs, one for recipient and one for change
    final feeForTwoOutputs =
        ((42 + 272 * inputsBeingConsumed + 128 * 2) / 4).ceil() *
            selectedTxFee.ceil();

    if (satoshisBeingUsed - satoshiAmountToSend > feeForOneOutput) {
      if (satoshisBeingUsed - satoshiAmountToSend > feeForOneOutput + 293) {
        // Here, we know that theoretically, we may be able to include another output(change) but we first need to
        // factor in the value of this output in satoshis.
        int changeOutputSize =
            satoshisBeingUsed - satoshiAmountToSend - feeForTwoOutputs;
        // We check to see if the user can pay for the new transaction with 2 outputs instead of one. Iff they can and
        // the second output's size > 293 satoshis, we perform the mechanics required to properly generate and use a new
        // change address.
        if (changeOutputSize > 293 &&
            satoshisBeingUsed - satoshiAmountToSend - changeOutputSize ==
                feeForTwoOutputs) {
          await incrementAddressIndex();
          final keys = ECPair.makeRandom(network: ravencoinLiteNetwork);

          final String newChangeAddress = await generateAddress(keys);
          await addToAddressesArray(newChangeAddress, "", "");
          recipientsArray.add(newChangeAddress);
          recipientsAmtArray.add(changeOutputSize);
          // At this point, we have the outputs we're going to use, the amounts to send along with which addresses
          // we intend to send these amounts to. We have enough to send instructions to build the transaction.
          print('2 outputs in tx');
          print('Input size: $satoshisBeingUsed');
          print('Recipient output size: $satoshiAmountToSend');
          print('Change Output Size: $changeOutputSize');
          dynamic hex = await buildTransaction(
              utxoObjectsToUse, recipientsArray, recipientsAmtArray);
          Map<String, dynamic> transactionObject = {
            "hex": hex,
            "recipient": recipientsArray[0],
            "recipientAmt": recipientsAmtArray[0],
            "fee": satoshisBeingUsed - satoshiAmountToSend - changeOutputSize
          };
          return transactionObject;
        } else {
          // Something went wrong here. It either overshot or undershot the estimated fee amount or the changeOutputSize
          // is smaller than or equal to 293. Revert to single output transaction.
          print('1 output in tx');
          print('Input size: $satoshisBeingUsed');
          print('Recipient output size: $satoshiAmountToSend');
          print('Difference (fee being paid): ' +
              (satoshisBeingUsed - satoshiAmountToSend).toString() +
              ' sats');
          print('Actual fee: $feeForOneOutput');
          dynamic hex = await buildTransaction(
              utxoObjectsToUse, recipientsArray, recipientsAmtArray);
          Map<String, dynamic> transactionObject = {
            "hex": hex,
            "recipient": recipientsArray[0],
            "recipientAmt": recipientsAmtArray[0],
            "fee": satoshisBeingUsed - satoshiAmountToSend
          };
          return transactionObject;
        }
      } else {
        // No additional outputs needed since adding one would mean that it'd be smaller than 293 sats
        // which makes it uneconomical to add to the transaction. Here, we pass data directly to instruct
        // the wallet to begin crafting the transaction that the user requested.
        print('1 output in tx');
        print('Input size: $satoshisBeingUsed');
        print('Recipient output size: $satoshiAmountToSend');
        print('Difference (fee being paid): ' +
            (satoshisBeingUsed - satoshiAmountToSend).toString() +
            ' sats');
        print('Actual fee: $feeForOneOutput');
        dynamic hex = await buildTransaction(
            utxoObjectsToUse, recipientsArray, recipientsAmtArray);
        Map<String, dynamic> transactionObject = {
          "hex": hex,
          "recipient": recipientsArray[0],
          "recipientAmt": recipientsAmtArray[0],
          "fee": satoshisBeingUsed - satoshiAmountToSend
        };
        return transactionObject;
      }
    } else if (satoshisBeingUsed - satoshiAmountToSend == feeForOneOutput) {
      // In this scenario, no additional change output is needed since inputs - outputs equal exactly
      // what we need to pay for fees. Here, we pass data directly to instruct the wallet to begin
      // crafting the transaction that the user requested.
      print('1 output in tx');
      print('Input size: $satoshisBeingUsed');
      print('Recipient output size: $satoshiAmountToSend');
      print('Fee being paid: ' +
          (satoshisBeingUsed - satoshiAmountToSend).toString() +
          ' sats');
      dynamic hex = await buildTransaction(
          utxoObjectsToUse, recipientsArray, recipientsAmtArray);
      Map<String, dynamic> transactionObject = {
        "hex": hex,
        "recipient": recipientsArray[0],
        "recipientAmt": recipientsAmtArray[0],
        "fee": feeForOneOutput
      };
      return transactionObject;
    } else {
      // Remember that returning 2 indicates that the user does not have a sufficient balance to
      // pay for the transaction fee. Ideally, at this stage, we should check if the user has any
      // additional outputs they're able to spend and then recalculate fees.
      print('Cannot pay tx fee - cancelling transaction');
      return 2;
    }
  }

  /// Builds and signs a transaction
  Future<dynamic> buildTransaction(List<UtxoObject> utxosToUse,
      List<String> recipients, List<int> satoshisPerRecipient) async {
    List<String> addressesToDerive = [];

    // Populating the addresses to derive
    for (var i = 0; i < utxosToUse.length; i++) {
      List<dynamic> lookupData = [utxosToUse[i].txid, utxosToUse[i].vout];
      Map<String, dynamic> requestBody = {
        "url": await getAPIUrl(),
        "lookupData": lookupData,
      };

      final response = await http.post(
        'https://us-central1-paymint.cloudfunctions.net/api/voutLookup',
        body: json.encode(requestBody),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        addressesToDerive.add(json.decode(response.body));
      } else {
        throw Exception('Something happened: ' +
            response.statusCode.toString() +
            response.body);
      }
    }

    final secureStore = new FlutterSecureStorage();
    final seed = bip39.mnemonicToSeed(await secureStore.read(key: 'mnemonic'));
    final root = bip32.BIP32.fromSeed(seed);

    List<ECPair> elipticCurvePairArray = [];
    List<Uint8List> outputDataArray = [];

    for (var i = 0; i < addressesToDerive.length; i++) {
      final addressToCheckFor = addressesToDerive[i];

      for (var i = 0; i < 2000; i++) {
        final nodeReceiving = root.derivePath("m/84'/0'/0'/0/$i");
        final nodeChange = root.derivePath("m/84'/0'/0'/1/$i");

        if (P2WPKH(data: new PaymentData(pubkey: nodeReceiving.publicKey))
                .data
                .address ==
            addressToCheckFor) {
          print('Receiving found on loop $i');
          elipticCurvePairArray.add(ECPair.fromWIF(nodeReceiving.toWIF()));
          outputDataArray.add(
              P2WPKH(data: new PaymentData(pubkey: nodeReceiving.publicKey))
                  .data
                  .output);
          break;
        }
        if (P2WPKH(data: new PaymentData(pubkey: nodeChange.publicKey))
                .data
                .address ==
            addressToCheckFor) {
          print('Change found on loop $i');
          elipticCurvePairArray.add(ECPair.fromWIF(nodeChange.toWIF()));
          outputDataArray.add(
              P2WPKH(data: new PaymentData(pubkey: nodeChange.publicKey))
                  .data
                  .output);
          break;
        }
      }
    }

    final txb = new TransactionBuilder();
    txb.setVersion(1);

    // Add transaction inputs
    for (var i = 0; i < utxosToUse.length; i++) {
      txb.addInput(
          utxosToUse[i].txid, utxosToUse[i].vout, null, outputDataArray[i]);
    }
    // Add transaction outputs
    for (var i = 0; i < recipients.length; i++) {
      txb.addOutput(recipients[i], satoshisPerRecipient[i]);
    }

    // Sign the transaction accordingly
    for (var i = 0; i < utxosToUse.length; i++) {
      txb.sign(
        vin: i,
        keyPair: elipticCurvePairArray[i],
        witnessValue: utxosToUse[i].value,
      );
    }
    return txb.build().toHex();
  }

  Future<String> getAPIUrl() async {
    final wallet = await Hive.openBox('wallet');
    final String url = await wallet.get('api_url');

    if (url == null) {
      final apiUrl = 'https://api.ravencoinlite.org/';
      print('Using api.ravencoinlite.org for api server');
      await wallet.put('api_url', apiUrl);
      return apiUrl;
    } else {
      return url;
    }
  }

  Future<bool> submitHexToNetwork(String hex) async {
    final Map<String, dynamic> obj = {
      "url": await getAPIUrl(),
      "hex": hex,
    };

    final res = await http.post(
      'https://us-central1-paymint.cloudfunctions.net/api/pushtx',
      body: jsonEncode(obj),
      headers: {'Content-Type': 'application/json'},
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      print(res.body.toString());
      return true;
    } else {
      print(res.body.toString());
      return false;
    }
  }

  Future<List<ReceivingAddresses>> _fetchReceivingAddresses() async {
    final wallet = await Hive.openBox('wallet');
    final List<ReceivingAddresses> receivingAddresses =
        await wallet.get('receivingAddresses');

    return receivingAddresses;
  }

  Future<UtxoData> _fetchUtxoData() async {
    final wallet = await Hive.openBox('wallet');
    final List<String> allAddresses = [];
    final String currency = await CurrencyUtilities.fetchPreferredCurrency();
    print('currency: ' + currency);
    final List receivingAddresses = await wallet.get('receivingAddresses');

    List<String> txHistory = [];

    final ravencoinLitePrice = await getRavencoinLitePrice();

    try {
      for (var i = 0; i < receivingAddresses.length; i++) {
        int offset = 0;
        //String url =
        //    'https://api.ravencoinlite.org/history/' + receivingAddresses[i];

        String url =
            'https://api.ravencoinlite.org/history/RXt29uFKBr8RnyUqyp7m71S4DXPtauYyXm';

        final response = await http.get(
          url + "?offset=" + offset.toString(),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          print('History fetched');
          Map<String, dynamic> map = json.decode(response.body);
          int txCount = map["result"]["txcount"];
          if (txCount > 0) {
            for (String tx in map["result"]["tx"]) {
              txHistory.add(tx);
            }
          }
          for (offset = 10; offset < txCount; offset += 10) {
            //for (offset = 10; offset < 20; offset += 10) {
            final history = await http.get(
              url + "?offset=" + offset.toString(),
              headers: {'Content-Type': 'application/json'},
            );
            if (history.statusCode == 200 || history.statusCode == 201) {
              Map<String, dynamic> map = json.decode(history.body);
              for (String tx in map["result"]["tx"]) {
                txHistory.add(tx);
              }
            }
          }
          print("TX Count: " + txCount.toString());
          print("History Length: " + txHistory.length.toString());

          List<dynamic> outputArray = [];
          int satoshiBalance = 0;
          for (String tx in txHistory) {
            String url = 'https://api.ravencoinlite.org/transaction/' + tx;

            final response = await http.get(
              url + "?offset=" + offset.toString(),
              headers: {'Content-Type': 'application/json'},
            );
            if (response.statusCode == 200 || response.statusCode == 201) {
              Map<String, dynamic> itemMap = json.decode(response.body);

              int value = 0;
              int valueSat = 0;
              int voutN = 0;

              for (int i = 0; i < itemMap['result']['vout'].length; i++) {
                for (int j = 0;
                    j <
                        itemMap['result']['vout'][i]['scriptPubKey']
                                ['addresses']
                            .length;
                    j++) {
                  if (itemMap['result']['vout'][i]['scriptPubKey']['addresses']
                          [j] ==
                      'RXt29uFKBr8RnyUqyp7m71S4DXPtauYyXm') {
                    value = itemMap['result']['vout'][i]['value'];
                    valueSat = itemMap['result']['vout'][i]['valueSat'];
                    voutN = itemMap['result']['vout'][i]['n'];
                  }
                }
              }

              bool confirmed = false;
              if (itemMap['result']['confirmations'] >= 100) {
                confirmed = true;
                satoshiBalance = satoshiBalance + valueSat;
              }

              final outputRvlValue = value / 100000000;
              final outputRvlPrice =
                  double.tryParse(ravencoinLitePrice) * outputRvlValue;
              Map<String, dynamic> outputMap = {
                'txid': itemMap['result']['txid'],
                'vout': voutN,
                'status': {
                  'confirmed': confirmed,
                  'block_height': itemMap['result']['height'],
                  'block_hash': itemMap['result']['hash'],
                  'block_time': itemMap['result']['time']
                },
                'value': value,
                'rawWorth': outputRvlPrice,
                'fiatWorth': CurrencyFormatter().format(
                    outputRvlPrice,
                    new CurrencyFormatterSettings(
                        symbol: '\$',
                        decimalSeparator: ".",
                        thousandSeparator: ",",
                        symbolSide: SymbolSide.left))
              };
              outputArray.add(outputMap);
            }
          }

          final currencyBalance = CurrencyFormatter().format(
              double.tryParse(ravencoinLitePrice) *
                  (satoshiBalance / 100000000),
              new CurrencyFormatterSettings(
                  symbol: '\$',
                  decimalSeparator: ".",
                  thousandSeparator: ",",
                  symbolSide: SymbolSide.left));

          Map<String, dynamic> utxoData = {
            'total_user_currency': currencyBalance,
            'total_sats': satoshiBalance,
            'total_rvl': satoshiBalance / 100000000,
            'outputArray': outputArray
          };

          var outputList = utxoData['outputArray'] as List;

          final List<UtxoObject> allOutputs =
              UtxoData.fromJson(utxoData).unspentOutputArray;
          await _sortOutputs(allOutputs);
          await wallet.put('latest_utxo_model', UtxoData.fromJson(utxoData));
          notifyListeners();
          // print(json.decode(response.body));
          return UtxoData.fromJson(utxoData);
        } else {
          print("Output fetch unsuccessful");
          final latestTxModel = await wallet.get('latest_utxo_model');

          if (latestTxModel == null) {
            final currency = await CurrencyUtilities.fetchPreferredCurrency();
            final currencySymbol = currencyMap[currency];

            final emptyModel = {
              "total_user_currency": "${currencySymbol}0.00",
              "total_sats": 0,
              "total_rvl": 0,
              "outputArray": []
            };
            return UtxoData.fromJson(emptyModel);
          } else {
            print("Old output model located");
            return latestTxModel;
          }
        }
      }
    } catch (e) {
      print("Output fetch unsuccessful");
      final latestTxModel = await wallet.get('latest_utxo_model');
      final currency = await CurrencyUtilities.fetchPreferredCurrency();
      final currencySymbol = currencyMap[currency];

      if (latestTxModel == null) {
        final emptyModel = {
          "total_user_currency": "${currencySymbol}0.00",
          "total_sats": 0,
          "total_rvl": 0,
          "outputArray": []
        };
        return UtxoData.fromJson(emptyModel);
      } else {
        print("Old output model located");
        return latestTxModel;
      }
    }
  }

  Future<TransactionData> _fetchTransactionData() async {
    final wallet = await Hive.openBox('wallet');
    final List<String> allAddresses = [];
    final String currency = await CurrencyUtilities.fetchPreferredCurrency();
    final List receivingAddresses = await wallet.get('receivingAddresses');
    final List changeAddresses = [];

    for (var i = 0; i < receivingAddresses.length; i++) {
      allAddresses.add(receivingAddresses[i]);
    }

    allAddresses.add('1KFHE7w8BhaENAswwryaoccDb6qcT6DbYY');

    final Map<String, dynamic> requestBody = {
      "currency": currency,
      "allAddresses": allAddresses,
      "changeAddresses": changeAddresses,
      "url": "https://www.blockstream.info/api" //await getAPIUrl()
    };

    try {
      final response = await http.post(
        'https://us-central1-paymint.cloudfunctions.net/api/txData',
        body: jsonEncode(requestBody),
        headers: {'Content-Type': 'application/json'},
      );

      print(json.decode(response.body));

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Transactions fetched');
        notifyListeners();
        await wallet.put('latest_tx_model',
            TransactionData.fromJson(json.decode(response.body)));
        return TransactionData.fromJson(json.decode(response.body));
      } else {
        print("Transaction fetch unsuccessful");
        final latestModel = await wallet.get('latest_tx_model');

        if (latestModel == null) {
          final emptyModel = {"dateTimeChunks": []};
          return TransactionData.fromJson(emptyModel);
        } else {
          print("Old transaction model located");
          print(response.body);
          return latestModel;
        }
      }
    } catch (e) {
      print("Transaction fetch unsuccessful");
      final latestModel = await wallet.get('latest_tx_model');

      if (latestModel == null) {
        final emptyModel = {"dateTimeChunks": []};
        return TransactionData.fromJson(emptyModel);
      } else {
        print("Old transaction model located");
        return latestModel;
      }
    }
  }

  Future<ChartModel> getChartData() async {
    int timeto = new DateTime.now().millisecondsSinceEpoch.abs();
    timeto = timeto ~/ 1000;
    int timefrom = new DateTime.now()
        .subtract(const Duration(days: 90))
        .millisecondsSinceEpoch
        .abs();
    timefrom = timefrom ~/ 1000;

    String url =
        'https://www.exbitron.com/api/v2/peatio/public/markets/rvlusdt/k-line?period=120&time_from=' +
            timefrom.toString() +
            '&time_to=' +
            timeto.toString();

    print(url);

    final response = await http.get(
      url,
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return ChartModel.fromJson(json.decode(response.body));
    } else {
      throw Exception('Something happened: ' +
          response.statusCode.toString() +
          response.body);
    }
  }

  Future<dynamic> getRavencoinLitePrice() async {
    final response = await http.get(
      'https://www.exbitron.com/api/v2/peatio/public/markets/rvlusdt/tickers',
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      notifyListeners();
      Map<String, dynamic> map = jsonDecode(response.body);
      String price = map["ticker"]["last"];
      if (price != null) {
        return price;
      } else {
        throw Exception('Something happened: ' +
            response.statusCode.toString() +
            response.body);
      }
    } else {
      throw Exception('Something happened: ' +
          response.statusCode.toString() +
          response.body);
    }
  }

  Future<void> checkReceivingAddressForTransactions() async {
    final String currentExternalAddr = await this._getCurrentAddress();

    String apiURL = await getAPIUrl();
    apiURL = apiURL + "history/" + currentExternalAddr;
    final response = await http.get(apiURL);

    if (response.statusCode == 200 || response.statusCode == 201) {
      Map<String, dynamic> map = jsonDecode(response.body);
      final int numTxs = map["result"]["txcount"];
      print('Number of txs for current receiving addr: ' + numTxs.toString());

      if (numTxs >= 1) {
        await incrementAddressIndex(); // First increment the receiving index
        final keys = ECPair.makeRandom(network: ravencoinLiteNetwork);
        final newReceivingAddress = await generateAddress(
            keys); // Use new index to derive a new receiving address
        await addToAddressesArray(newReceivingAddress, "",
            ""); // Add that new receiving address to the array of receiving addresses
        this._currentReceivingAddress = Future(() =>
            newReceivingAddress); // Set the new receiving address that the service
        notifyListeners();
      }
    } else {
      throw Exception('Something happened: ' +
          response.statusCode.toString() +
          response.body);
    }
  }

  Future<FeeObject> getFees() async {
    final Map<String, dynamic> requestBody = {"url": await getAPIUrl()};

    final response = await http.post(
      'https://us-central1-paymint.cloudfunctions.net/api/fees',
      body: jsonEncode(requestBody),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final FeeObject feeObj = FeeObject.fromJson(json.decode(response.body));
      return feeObj;
    } else {
      throw Exception('Something happened: ' +
          response.statusCode.toString() +
          response.body);
    }
  }

  Future<String> getMarketInfo() async {
    final response = await http.get(
      'https://www.exbitron.com/api/v2/peatio/public/markets/rvlusdt/tickers',
      headers: {'Content-Type': 'application/json'},
      // ignore: invalid_return_type_for_catch_error
    ).catchError((error) => Future(() => 'Unable to fetch market data'));

    if (response.statusCode == 200 || response.statusCode == 201) {
      Map<String, dynamic> map = jsonDecode(response.body);
      String marketData = "  Last price: " +
          map["ticker"]["last"] +
          "  24 hour change: " +
          map["ticker"]["price_change_percent"] +
          "  24 hour high: " +
          map["ticker"]["high"] +
          "  24 hour low: " +
          map["ticker"]["low"] +
          "  24 hour volume: " +
          map["ticker"]["volume"];

      return marketData;
    } else {
      return Future(() => 'Unable to fetch market data');
    }
  }

  /// Recovers wallet from [suppliedMnemonic]. Expects a valid mnemonic.
  dynamic recoverWalletFromWIF(String suppliedWif) async {
    final ECPair keys = ECPair.fromWIF(suppliedWif);

    List<String> receivingAddressArray = [];

    final address = P2PKH(
            data: new PaymentData(pubkey: keys.publicKey),
            network: ravencoinLiteNetwork)
        .data
        .address;

    receivingAddressArray.add(address);

    final wallet = await Hive.openBox('wallet');
    await wallet.put('receivingAddresses', receivingAddressArray);

    final secureStore = new FlutterSecureStorage();
    await secureStore.write(key: 'Wif', value: HEX.encode(keys.privateKey));
    notifyListeners();
  }
}
