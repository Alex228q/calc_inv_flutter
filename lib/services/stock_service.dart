import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/stock.dart';

class StockService {
  static const List<Map<String, String>> _stocksInfo = [
    {'ticker': 'X5', 'name': 'X5', 'lotSize': '1'},
    {'ticker': 'MDMG', 'name': 'Мать и дитя', 'lotSize': '1'},
    {'ticker': 'NVTK', 'name': 'Новатэк', 'lotSize': '1'},
    {'ticker': 'OZON', 'name': 'Ozon', 'lotSize': '1'},
    {'ticker': 'PLZL', 'name': 'Полюс', 'lotSize': '1'},
    {'ticker': 'SBERP', 'name': 'Сбербанк', 'lotSize': '1'},
    {'ticker': 'CHMF', 'name': 'Северсталь', 'lotSize': '1'},
    {'ticker': 'TATNP', 'name': 'Татнефть', 'lotSize': '1'},
    {'ticker': 'PHOR', 'name': 'Фосагро', 'lotSize': '1'},
    {'ticker': 'YDEX', 'name': 'Yandex', 'lotSize': '1'},
  ];

  Future<List<Stock>> fetchStockPrices() async {
    final List<Stock> loadedStocks = [];

    for (var stockInfo in _stocksInfo) {
      final ticker = stockInfo['ticker']!;
      final lotSize = int.parse(stockInfo['lotSize']!);

      final price = await _fetchStockPrice(ticker);

      if (price != null) {
        loadedStocks.add(
          Stock(
            secId: ticker,
            shortName: stockInfo['name']!,
            lastPrice: price,
            lotSize: lotSize,
          ),
        );
      }
    }

    return loadedStocks;
  }

  Future<double?> _fetchStockPrice(String ticker) async {
    try {
      final priceUrl = Uri.parse(
        'https://iss.moex.com/iss/engines/stock/markets/shares/boards/TQBR/securities/$ticker.json?'
        'iss.meta=off&'
        'securities.columns=SECID,SECNAME,PREVPRICE&'
        'marketdata.columns=LAST',
      );

      final priceResponse = await http.get(priceUrl);

      if (priceResponse.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(priceResponse.body);

        double? currentPrice;

        if (data['marketdata'] != null && data['marketdata']['data'] != null) {
          final marketData = data['marketdata']['data'];
          if (marketData.isNotEmpty && marketData[0].isNotEmpty) {
            currentPrice = double.tryParse(marketData[0][0]?.toString() ?? '0');
          }
        }

        if (currentPrice == null || currentPrice == 0) {
          if (data['securities'] != null &&
              data['securities']['data'] != null) {
            final securitiesData = data['securities']['data'];
            if (securitiesData.isNotEmpty && securitiesData[0].length > 2) {
              currentPrice = double.tryParse(
                securitiesData[0][2]?.toString() ?? '0',
              );
            }
          }
        }

        return currentPrice ?? 0.0;
      }
    } catch (e) {
      // В случае ошибки возвращаем null
    }

    return null;
  }

  static List<Map<String, String>> get stocksInfo => _stocksInfo;
}
