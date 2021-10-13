import 'package:hive/hive.dart';
//part 'type_adaptors/address_model.g.dart';

@HiveType(typeId: 9)
class ReceivingAddresses {
  @HiveField(0)
  final List<dynamic> addresses;
  @HiveField(1)
  final List<dynamic> publicKeys;
  @HiveField(2)
  final List<dynamic> privateKeys;

  ReceivingAddresses({this.addresses, this.publicKeys, this.privateKeys});
}
