import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Stock {
  final String secId;
  final double lastPrice;
  final String shortName;
  final int lotSize;

  Stock({
    required this.secId,
    required this.lastPrice,
    required this.shortName,
    required this.lotSize,
  });

  @override
  String toString() {
    return 'Stock{secId: $secId, lastPrice: $lastPrice, shortName: $shortName, lotSize: $lotSize}';
  }
}

class StockAllocation {
  final Stock stock;
  int lots;
  int existingLots;
  double totalCost;
  double percentage;
  double existingCost;
  double existingPercentage;

  StockAllocation({
    required this.stock,
    required this.lots,
    required this.existingLots,
    required this.totalCost,
    required this.percentage,
    required this.existingCost,
    required this.existingPercentage,
  });
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Цены акций',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const StockPriceScreen(),
    );
  }
}

class StockPriceScreen extends StatefulWidget {
  const StockPriceScreen({super.key});

  @override
  State<StockPriceScreen> createState() => _StockPriceScreenState();
}

class _StockPriceScreenState extends State<StockPriceScreen> {
  final List<Map<String, String>> _stocksInfo = [
    {'ticker': 'X5', 'name': 'X5', 'lotSize': '1'},
    {'ticker': 'NVTK', 'name': 'НОВАТЭК', 'lotSize': '1'},
    {'ticker': 'GMKN', 'name': 'Норникель', 'lotSize': '10'},
    {'ticker': 'OZON', 'name': 'OZON', 'lotSize': '1'},
    {'ticker': 'MDMG', 'name': 'Мать и Дитя', 'lotSize': '1'},
    {'ticker': 'OZPH', 'name': 'ОзонФарм', 'lotSize': '10'},
    {'ticker': 'PLZL', 'name': 'Полюс', 'lotSize': '1'},
    {'ticker': 'SBERP', 'name': 'Сбербанк', 'lotSize': '1'},
    {'ticker': 'CHMF', 'name': 'Северсталь', 'lotSize': '1'},
    {'ticker': 'TATNP', 'name': 'Татнефть', 'lotSize': '1'},
    {'ticker': 'PHOR', 'name': 'ФосАгро', 'lotSize': '1'},
    {'ticker': 'YDEX', 'name': 'ЯНДЕКС', 'lotSize': '1'},
  ];

  List<Stock> _stocks = [];
  bool _isLoading = true;
  String _error = '';
  final TextEditingController _amountController = TextEditingController();
  final List<TextEditingController> _existingSharesControllers = [];
  List<StockAllocation> _allocations = [];
  bool _showAllocation = false;

  @override
  void initState() {
    super.initState();
    // Инициализируем контроллеры для существующих акций (штук)
    for (int i = 0; i < _stocksInfo.length; i++) {
      _existingSharesControllers.add(TextEditingController(text: ''));
    }
    _fetchStockPrices();
  }

  Future<void> _fetchStockPrices() async {
    setState(() {
      _isLoading = true;
      _error = '';
      _showAllocation = false;
    });

    try {
      final List<Stock> loadedStocks = [];

      for (var stockInfo in _stocksInfo) {
        final ticker = stockInfo['ticker']!;
        final lotSize = int.parse(stockInfo['lotSize']!);

        // Получаем текущую цену
        final stockData = await _fetchStockData(ticker);

        if (stockData['price'] != null) {
          loadedStocks.add(
            Stock(
              secId: ticker,
              shortName: stockInfo['name']!,
              lastPrice: stockData['price']!,
              lotSize: lotSize,
            ),
          );
        }
      }

      setState(() {
        _stocks = loadedStocks;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
        _error = 'Ошибка загрузки: $error';
      });
    }
  }

  Future<Map<String, double?>> _fetchStockData(String ticker) async {
    try {
      // Получаем текущую цену
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

        // Пытаемся получить цену из marketdata (LAST)
        if (data['marketdata'] != null && data['marketdata']['data'] != null) {
          final marketData = data['marketdata']['data'];
          if (marketData.isNotEmpty && marketData[0].isNotEmpty) {
            currentPrice = double.tryParse(marketData[0][0]?.toString() ?? '0');
          }
        }

        // Если не получили из marketdata, используем PREVPRICE из securities
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

        return {'price': currentPrice ?? 0.0};
      }
    } catch (e) {}

    return {'price': null};
  }

  // Метод для расчета равных целевых процентов
  List<double> _calculateTargetPercentages() {
    final int stockCount = _stocks.length;
    final double basePercentage = 100.0 / stockCount;

    List<double> targetPercentages = [];
    for (int i = 0; i < stockCount; i++) {
      targetPercentages.add(basePercentage);
    }

    return targetPercentages;
  }

  // Метод для ребалансировки портфеля
  void _rebalancePortfolio() {
    if (_stocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нет данных об акциях для ребалансировки'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Рассчитываем текущую стоимость портфеля
    double currentPortfolioValue = 0;
    final List<double> currentCosts = [];

    for (int i = 0; i < _stocks.length; i++) {
      final stock = _stocks[i];
      final existingShares =
          int.tryParse(_existingSharesControllers[i].text) ?? 0;
      final double cost = existingShares * stock.lastPrice;
      currentCosts.add(cost);
      currentPortfolioValue += cost;
    }

    if (currentPortfolioValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите имеющиеся акции для ребалансировки'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Рассчитываем целевые доли (равные)
    final List<double> targetPercentages = _calculateTargetPercentages();

    // Рассчитываем целевые суммы для каждой акции
    final List<double> targetAmounts = [];
    for (int i = 0; i < _stocks.length; i++) {
      final double targetAmount =
          (targetPercentages[i] / 100) * currentPortfolioValue;
      targetAmounts.add(targetAmount);
    }

    // Рассчитываем необходимое количество акций для каждой позиции
    for (int i = 0; i < _stocks.length; i++) {
      final stock = _stocks[i];
      final double targetAmount = targetAmounts[i];
      final int targetShares = (targetAmount / stock.lastPrice).round();

      // Обновляем поле ввода
      _existingSharesControllers[i].text = targetShares.toString();
    }

    setState(() {
      _showAllocation = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Портфель ребалансирован! Общая стоимость: ${currentPortfolioValue.toStringAsFixed(2)} ₽',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _calculateAllocation() {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите корректную сумму для расчета'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_stocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нет данных об акциях для расчета'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Собираем информацию о существующих акциях
    final List<int> existingShares = [];
    for (int i = 0; i < _stocks.length; i++) {
      final shares = int.tryParse(_existingSharesControllers[i].text) ?? 0;
      existingShares.add(shares);
    }

    // Рассчитываем текущую стоимость портфеля
    double currentPortfolioValue = 0;
    final List<double> sharePrices = [];
    final List<double> existingCosts = [];

    for (int i = 0; i < _stocks.length; i++) {
      final stock = _stocks[i];
      final double sharePrice = stock.lastPrice;
      final double cost = existingShares[i] * sharePrice;

      sharePrices.add(sharePrice);
      existingCosts.add(cost);
      currentPortfolioValue += cost;
    }

    final double totalPortfolioValue = currentPortfolioValue + amount;

    // Рассчитываем целевые доли (равные)
    final List<double> targetPercentages = _calculateTargetPercentages();

    // Рассчитываем целевые суммы для каждой акции
    final List<double> targetAmounts = [];
    for (int i = 0; i < _stocks.length; i++) {
      final double targetAmount =
          (targetPercentages[i] / 100) * totalPortfolioValue;
      targetAmounts.add(targetAmount);
    }

    // Инициализация allocations
    List<StockAllocation> allocations = [];
    for (int i = 0; i < _stocks.length; i++) {
      final stock = _stocks[i];
      final double existingCost = existingCosts[i];
      final double existingPercentage = currentPortfolioValue > 0
          ? (existingCost / currentPortfolioValue * 100)
          : 0;

      allocations.add(
        StockAllocation(
          stock: stock,
          lots: 0,
          existingLots: (existingShares[i] / stock.lotSize).floor(),
          totalCost: 0,
          percentage: existingPercentage,
          existingCost: existingCost,
          existingPercentage: existingPercentage,
        ),
      );
    }

    double remainingAmount = amount;

    // НОВЫЙ АЛГОРИТМ: Плавное распределение между всеми отстающими акциями
    bool changed = true;
    int iterations = 0;
    int maxIterations = 1000;

    while (remainingAmount > 0 && changed && iterations < maxIterations) {
      changed = false;

      // Находим ВСЕ отстающие акции, которые можно докупить
      final List<Map<String, dynamic>> underweightStocks = [];

      for (int i = 0; i < allocations.length; i++) {
        final allocation = allocations[i];
        final stock = _stocks[i];
        final double sharePrice = sharePrices[i];
        final double targetAmount = targetAmounts[i];

        // Текущая общая стоимость (имеющиеся + купленные)
        final double currentTotalAmount =
            allocation.existingCost + allocation.totalCost;

        // Отклонение от целевой суммы (положительное = недобор)
        final double deviationFromTarget = targetAmount - currentTotalAmount;

        // Можем ли купить хотя бы 1 лот?
        final double lotCost = sharePrice * stock.lotSize;
        if (deviationFromTarget > 0 && lotCost <= remainingAmount) {
          underweightStocks.add({
            'index': i,
            'allocation': allocation,
            'sharePrice': sharePrice,
            'deviation': deviationFromTarget,
            'lotSize': stock.lotSize,
            'lotCost': lotCost,
            'currentPercentage':
                (currentTotalAmount / totalPortfolioValue * 100),
            'targetPercentage': targetPercentages[i],
          });
        }
      }

      // Если есть отстающие акции для покупки
      if (underweightStocks.isNotEmpty) {
        // Сортируем по величине недобора (самые недооцененные сначала)
        underweightStocks.sort(
          (a, b) => b['deviation'].compareTo(a['deviation']),
        );

        // Ограничиваем количество рассматриваемых акций для более плавного распределения
        final int maxStocksToConsider =
            underweightStocks.length; // Рассматриваем все

        // Распределяем покупку лота между несколькими самыми отстающими акциями
        int stocksBoughtInThisRound = 0;

        for (int i = 0; i < maxStocksToConsider; i++) {
          if (i >= underweightStocks.length) break;

          final stockInfo = underweightStocks[i];
          final int index = stockInfo['index'];
          final allocation = stockInfo['allocation'];
          final double lotCost = stockInfo['lotCost'];

          // Проверяем, можем ли купить еще один лот
          if (lotCost <= remainingAmount) {
            // Покупаем 1 лот
            allocations[index] = StockAllocation(
              stock: allocation.stock,
              lots: allocation.lots + 1,
              existingLots: allocation.existingLots,
              totalCost: allocation.totalCost + lotCost,
              percentage:
                  (allocation.existingCost + allocation.totalCost + lotCost) /
                  totalPortfolioValue *
                  100,
              existingCost: allocation.existingCost,
              existingPercentage: allocation.existingPercentage,
            );

            remainingAmount -= lotCost;
            changed = true;
            stocksBoughtInThisRound++;

            // После покупки 1-3 лотов в этом раунде, прерываем для балансировки
            if (stocksBoughtInThisRound >= 3) {
              break;
            }
          }
        }
      }

      iterations++;
    }

    // ЕСЛИ ВСЕ ЕЩЕ ОСТАЛИСЬ СРЕДСТВА - покупаем по одному лоту самых отстающих
    if (remainingAmount > 0) {
      changed = true;
      iterations = 0;

      while (remainingAmount > 0 && changed && iterations < maxIterations) {
        changed = false;

        final List<Map<String, dynamic>> affordableStocks = [];

        for (int i = 0; i < allocations.length; i++) {
          final allocation = allocations[i];
          final stock = _stocks[i];
          final double sharePrice = sharePrices[i];
          final double lotCost = sharePrice * stock.lotSize;
          final double targetAmount = targetAmounts[i];
          final double currentTotalAmount =
              allocation.existingCost + allocation.totalCost;
          final double deviationFromTarget = targetAmount - currentTotalAmount;

          // Покупаем если есть недобор и можем купить лот
          if (deviationFromTarget > 0 && lotCost <= remainingAmount) {
            affordableStocks.add({
              'index': i,
              'allocation': allocation,
              'lotCost': lotCost,
              'deviation': deviationFromTarget,
            });
          }
        }

        // Сортируем по недобору (самые недооцененные сначала)
        affordableStocks.sort(
          (a, b) => b['deviation'].compareTo(a['deviation']),
        );

        if (affordableStocks.isNotEmpty) {
          final stockInfo = affordableStocks.first;
          final int index = stockInfo['index'];
          final allocation = stockInfo['allocation'];
          final double lotCost = stockInfo['lotCost'];

          allocations[index] = StockAllocation(
            stock: allocation.stock,
            lots: allocation.lots + 1,
            existingLots: allocation.existingLots,
            totalCost: allocation.totalCost + lotCost,
            percentage:
                (allocation.existingCost + allocation.totalCost + lotCost) /
                totalPortfolioValue *
                100,
            existingCost: allocation.existingCost,
            existingPercentage: allocation.existingPercentage,
          );

          remainingAmount -= lotCost;
          changed = true;
        }

        iterations++;
      }
    }

    setState(() {
      _allocations = allocations;
      _showAllocation = true;
    });
  }

  Widget _buildCompactPriceInfo(double currentPrice) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${currentPrice.toStringAsFixed(2)} ₽',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Равная доля',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExistingSharesInputs() {
    if (_stocks.isEmpty) return const SizedBox();

    // Рассчитываем текущую стоимость портфеля для отображения процентов
    double currentPortfolioValue = 0;
    final List<double> existingCosts = [];

    for (int i = 0; i < _stocks.length; i++) {
      final stock = _stocks[i];
      final existingShares =
          int.tryParse(_existingSharesControllers[i].text) ?? 0;
      final int lotSize = stock.lotSize;
      final int lots = (existingShares / lotSize).floor();
      final double lotPrice = stock.lastPrice * stock.lotSize;
      final double cost = lots * lotPrice;
      existingCosts.add(cost);
      currentPortfolioValue += cost;
    }

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Уже имеющиеся акции (в штуках):',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _rebalancePortfolio,
                  icon: const Icon(Icons.autorenew, size: 20),
                  label: const Text('Ребалансировка'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            if (currentPortfolioValue > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Текущая стоимость портфеля: ${currentPortfolioValue.toStringAsFixed(2)} ₽',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Сетка с Wrap
            Wrap(
              spacing: 16.0, // горизонтальное расстояние
              runSpacing: 16.0, // вертикальное расстояние
              children: List.generate(_stocks.length, (index) {
                final stock = _stocks[index];
                final existingShares =
                    int.tryParse(_existingSharesControllers[index].text) ?? 0;
                final int lotSize = stock.lotSize;
                final int lots = (existingShares / lotSize).floor();
                final double lotPrice = stock.lastPrice * stock.lotSize;
                final double cost = lots * lotPrice;
                final double percentage = currentPortfolioValue > 0
                    ? (cost / currentPortfolioValue * 100)
                    : 0;

                return SizedBox(
                  width: 250, // фиксированная ширина 250 пикселей
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _existingSharesControllers[index],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: stock.shortName,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {});
                        },
                      ),

                      // Отображение стоимости и процента (если есть акции)
                      if (existingShares > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${cost.toStringAsFixed(2)} ₽',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.green,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      '$lots лотов',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12.0,
                                  vertical: 6.0,
                                ),
                                decoration: BoxDecoration(
                                  color: _getExistingPercentageColor(
                                    percentage,
                                  ),
                                  borderRadius: BorderRadius.circular(16.0),
                                ),
                                child: Text(
                                  '${percentage.toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllocationResults() {
    if (!_showAllocation || _allocations.isEmpty) {
      return const SizedBox();
    }

    final totalCost = _allocations.fold(
      0.0,
      (sum, allocation) => sum + allocation.totalCost,
    );

    // Исправление: безопасный парсинг суммы
    final amountText = _amountController.text;
    final amount = double.tryParse(amountText) ?? 0.0;
    final remaining = amount - totalCost;

    final totalLotsToBuy = _allocations.fold(
      0,
      (sum, allocation) => sum + allocation.lots,
    );
    final totalExistingCost = _allocations.fold(
      0.0,
      (sum, allocation) => sum + allocation.existingCost,
    );

    // Рассчитываем стандартное отклонение для оценки равномерности
    final double averagePercentage = 100.0 / _allocations.length;
    double deviationSum = 0;
    for (final allocation in _allocations) {
      deviationSum += (allocation.percentage - averagePercentage).abs();
    }
    final double averageDeviation = deviationSum / _allocations.length;

    // Фильтруем allocations, оставляя только те акции, которые нужно докупить
    final allocationsToShow = _allocations
        .where((allocation) => allocation.lots > 0)
        .toList();

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Результаты распределения:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Среднее отклонение от равных долей: ${averageDeviation.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 12,
                color: averageDeviation < 10 ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(height: 16),

            // Показываем только акции, которые нужно докупить
            if (allocationsToShow.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Не нужно докупать акции - портфель уже сбалансирован',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...allocationsToShow.map(
                (allocation) => Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Column(
                    children: [
                      // Показываем только информацию о покупке
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  allocation.stock.shortName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 18,
                                  ),
                                ),
                                if (allocation.existingLots > 0)
                                  Text(
                                    'Имеется: ${allocation.existingLots} лотов',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              'Купить: ${allocation.lots} лотов',
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Стоимость: ${allocation.totalCost.toStringAsFixed(2)} ₽',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                // ИЗМЕНЕНИЕ ЗДЕСЬ: показываем старые и новые проценты
                                Row(
                                  children: [
                                    Text(
                                      'Было: ${allocation.existingPercentage.toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(width: 50),
                                    Text(
                                      'Станет: ${allocation.percentage.toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.purple,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Divider(color: Colors.grey[300]),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Текущий портфель:'),
                Text(
                  '${totalExistingCost.toStringAsFixed(2)} ₽',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Всего купить лотов:'),
                Text(
                  '$totalLotsToBuy',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Общая стоимость покупки:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${totalCost.toStringAsFixed(2)} ₽',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Остаток:'),
                Text(
                  '${remaining.toStringAsFixed(2)} ₽',
                  style: TextStyle(
                    color: remaining > 0 ? Colors.orange : Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (remaining > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Недостаточно средств для покупки дополнительных лотов',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getExistingPercentageColor(double percentage) {
    final average = 100.0 / _stocks.length;
    final deviation = (percentage - average).abs();
    if (deviation < 5) return Colors.green;
    if (deviation < 15) return Colors.orange;
    return Colors.red;
  }

  Widget _buildStocksGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            'Текущие цены акций:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),

        Wrap(
          spacing: 16.0, // горизонтальное расстояние
          runSpacing: 16.0, // вертикальное расстояние
          children: List.generate(_stocks.length, (index) {
            final stock = _stocks[index];

            return SizedBox(
              width: 250, // фиксированная ширина 250 пикселей
              child: Card(
                margin: const EdgeInsets.all(0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Заголовок с тикером и названием
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.blue[50],
                            radius: 16,
                            child: Text(
                              stock.secId.substring(0, 1),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stock.shortName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  stock.secId,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Информация о лоте
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Лот: ${stock.lotSize} шт',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Цена
                      _buildCompactPriceInfo(stock.lastPrice),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Калькулятор покупок акций'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchStockPrices,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stocks.isEmpty
          ? const Center(
              child: Text(
                'Нет данных для отображения',
                style: TextStyle(fontSize: 16),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  if (_error.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      color: Colors.orange[100],
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Поле ввода суммы и кнопка расчета
                  Card(
                    margin: const EdgeInsets.all(8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Сумма для инвестирования (₽)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : _calculateAllocation,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Рассчитать распределение',
                                      style: TextStyle(fontSize: 16),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Поля для ввода имеющихся акций (штук)
                  _buildExistingSharesInputs(),

                  // Результаты распределения
                  _buildAllocationResults(),

                  // Список акций в сетке
                  _buildStocksGrid(),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    for (var controller in _existingSharesControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
