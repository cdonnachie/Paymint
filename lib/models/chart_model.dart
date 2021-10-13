import 'package:intl/intl.dart';

class ChartModel {
  final List<dynamic> xAxis;
  final List<dynamic> candleData;

  ChartModel({this.xAxis, this.candleData});

  factory ChartModel.fromJson(List<dynamic> kline) {
    List<dynamic> axis = [];
    List<dynamic> data = [];

    for (var v in kline) {
      DateTime klineDate =
          new DateTime.fromMillisecondsSinceEpoch(v[0] * 1000, isUtc: false);
      if (klineDate.minute == 0 ||
          klineDate.minute == 15 ||
          klineDate.minute == 30 ||
          klineDate.minute == 45) {
        axis.add(DateFormat('MM/dd/yyyy hh:mm').format((klineDate)));
        List<dynamic> items = [];
        items.add(v[1]);
        items.add(v[4]);
        items.add(v[3]);
        items.add(v[2]);
        data.add(items);
      }
    }

    return ChartModel(
      xAxis: axis,
      candleData: data,
    );
  }
}
