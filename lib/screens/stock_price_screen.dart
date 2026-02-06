import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../models/stock_allocation.dart';
import '../services/stock_service.dart';
import '../widgets/existing_shares_input.dart';
import '../widgets/allocation_results.dart';
import '../widgets/stocks_grid.dart';

class StockPriceScreen extends StatefulWidget {
  const StockPriceScreen({super.key});

  @override
  State<StockPriceScreen> createState() => _StockPriceScreenState();
}

class _StockPriceScreenState extends State<StockPriceScreen> {
  final StockService _stockService = StockService();
  List<Stock> _stocks = [];
  bool _isLoading = true;
  String _error = '';
  final TextEditingController _amountController = TextEditingController();
  final List<TextEditingController> _existingSharesControllers = [];
  List<StockAllocation> _allocations = [];
  bool _showAllocation = false;
  bool _useSmaAdjustment = true;
  bool _isLoadingSma = false;
  int _stocksWithSma = 0;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < StockService.stocksInfo.length; i++) {
      _existingSharesControllers.add(TextEditingController(text: ''));
    }
    _fetchStockPrices();
  }

  Future<void> _fetchStockPrices() async {
    setState(() {
      _isLoading = true;
      _isLoadingSma = true;
      _error = '';
      _showAllocation = false;
      _stocksWithSma = 0;
    });

    try {
      final loadedStocks = await _stockService.fetchStockPrices();

      // Считаем сколько акций имеют SMA данные
      final smaCount = loadedStocks
          .where((stock) => stock.sma200 != null)
          .length;

      setState(() {
        _stocks = loadedStocks;
        _isLoading = false;
        _isLoadingSma = false;
        _stocksWithSma = smaCount;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
        _isLoadingSma = false;
        _error = 'Ошибка загрузки: $error';
      });
    }
  }

  List<double> _calculateTargetPercentages() {
    const int stockCount = 10;
    const double minP = 7.5;
    const double maxP = 12.5;
    const double basePercentage = 10.0;

    if (!_useSmaAdjustment || _stocksWithSma == 0) {
      return List.filled(stockCount, basePercentage);
    }

    // 1. Рассчитываем с SMA и жесткими границами
    List<double> weights = _stocks.map((stock) {
      double adjustment = 0;
      if (stock.deviationFromSma != null) {
        final double coefficient = 0.3;
        adjustment = -stock.deviationFromSma! * coefficient;
        adjustment = adjustment.clamp(-2.5, 2.5);
      }

      return (basePercentage + adjustment).clamp(minP, maxP);
    }).toList();

    // 2. ПРОСТАЯ нормализация без нарушения границ
    return _simpleNormalize(weights, minP, maxP);
  }

  List<double> _simpleNormalize(
    List<double> weights,
    double minP,
    double maxP,
  ) {
    double sum = weights.fold(0.0, (a, b) => a + b);

    // Если сумма уже 100±0.1%, возвращаем
    if ((sum - 100.0).abs() < 0.1) {
      return weights.map((w) => double.parse(w.toStringAsFixed(1))).toList();
    }

    // Масштабируем
    double factor = 100.0 / sum;
    List<double> normalized = weights.map((w) => w * factor).toList();

    // Проверяем границы после масштабирования
    for (int i = 0; i < normalized.length; i++) {
      if (normalized[i] < minP) normalized[i] = minP;
      if (normalized[i] > maxP) normalized[i] = maxP;
    }

    // Если после этого сумма не 100%, корректируем последнюю акцию
    double finalSum = normalized.fold(0.0, (a, b) => a + b);
    if ((finalSum - 100.0).abs() > 0.1) {
      double diff = 100.0 - finalSum;
      normalized[normalized.length - 1] += diff;

      // Проверяем границу для скорректированной акции
      if (normalized.last < minP) normalized[normalized.length - 1] = minP;
      if (normalized.last > maxP) normalized[normalized.length - 1] = maxP;
    }

    return normalized.map((w) => double.parse(w.toStringAsFixed(1))).toList();
  }

  void _rebalancePortfolio() {
    if (_stocks.isEmpty) {
      _showSnackBar('Нет данных об акциях для ребалансировки', Colors.red);
      return;
    }

    double currentPortfolioValue = 0;
    for (int i = 0; i < _stocks.length; i++) {
      final stock = _stocks[i];
      final existingShares =
          int.tryParse(_existingSharesControllers[i].text) ?? 0;
      currentPortfolioValue += existingShares * stock.lastPrice;
    }

    if (currentPortfolioValue <= 0) {
      _showSnackBar('Введите имеющиеся акции для ребалансировки', Colors.red);
      return;
    }

    final List<double> targetPercentages = _calculateTargetPercentages();

    for (int i = 0; i < _stocks.length; i++) {
      final stock = _stocks[i];
      final double targetValue =
          (targetPercentages[i] / 100) * currentPortfolioValue;
      int targetShares = (targetValue / stock.lastPrice).round();
      targetShares = targetShares < 0 ? 0 : targetShares;
      _existingSharesControllers[i].text = targetShares.toString();
    }

    setState(() {
      _showAllocation = false;
    });

    _showSnackBar('Портфель ребалансирован', Colors.green);
  }

  void _calculateAllocation() {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showSnackBar('Введите корректную сумму для расчета', Colors.red);
      return;
    }

    if (_stocks.isEmpty) {
      _showSnackBar('Нет данных об акциях для расчета', Colors.red);
      return;
    }

    final List<int> existingShares = [];
    for (int i = 0; i < _stocks.length; i++) {
      final shares = int.tryParse(_existingSharesControllers[i].text) ?? 0;
      existingShares.add(shares);
    }

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
    final List<double> targetPercentages = _calculateTargetPercentages();

    _allocations = [];
    for (int i = 0; i < _stocks.length; i++) {
      final stock = _stocks[i];
      final double existingCost = existingCosts[i];
      final double existingPercentage = currentPortfolioValue > 0
          ? (existingCost / currentPortfolioValue * 100)
          : 0;

      _allocations.add(
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

    // УНИВЕРСАЛЬНЫЙ АЛГОРИТМ: Используем улучшенный алгоритм для всех случаев
    _allocateWithImprovedAlgorithm(
      amount,
      sharePrices,
      targetPercentages,
      currentPortfolioValue,
      totalPortfolioValue,
      existingCosts,
    );

    setState(() {
      _showAllocation = true;
    });
  }

  void _allocateWithImprovedAlgorithm(
    double amount,
    List<double> sharePrices,
    List<double> targetPercentages,
    double currentPortfolioValue,
    double totalPortfolioValue,
    List<double> existingCosts,
  ) {
    // Шаг 1: Рассчитываем целевые суммы для каждой акции
    final List<double> targetAmounts = [];
    for (int i = 0; i < _stocks.length; i++) {
      final double targetAmount =
          (targetPercentages[i] / 100) * totalPortfolioValue;
      targetAmounts.add(targetAmount);
    }

    // Шаг 2: Рассчитываем сколько нужно докупить для каждой акции
    final List<Map<String, dynamic>> stockData = [];
    double totalToSpend = 0;

    for (int i = 0; i < _stocks.length; i++) {
      final stock = _stocks[i];
      final double sharePrice = sharePrices[i];
      final double lotCost = sharePrice * stock.lotSize;
      final double targetAmount = targetAmounts[i];
      final double existingCost = existingCosts[i];

      // Сколько нужно докупить до цели (может быть отрицательным, если перекуп)
      final double neededAmount = targetAmount - existingCost;

      // Начальное количество лотов для докупки (округляем вниз)
      int lotsToBuy = 0;
      if (neededAmount > 0) {
        lotsToBuy = (neededAmount / lotCost).floor();
        lotsToBuy = lotsToBuy < 0 ? 0 : lotsToBuy;
      } else {
        // Если перекуп - не покупаем
        lotsToBuy = 0;
      }

      double buyCost = lotsToBuy * lotCost;

      stockData.add({
        'index': i,
        'stock': stock,
        'sharePrice': sharePrice,
        'lotCost': lotCost,
        'targetAmount': targetAmount,
        'existingCost': existingCost,
        'neededAmount': neededAmount,
        'lotsToBuy': lotsToBuy,
        'buyCost': buyCost,
        'totalCostAfterBuy': existingCost + buyCost,
        'deviationAfterBuy': targetAmount - (existingCost + buyCost),
      });

      totalToSpend += buyCost;
    }

    // Шаг 3: Проверяем, не превышает ли планируемая покупка доступную сумму
    double remainingAmount = amount;

    if (totalToSpend > amount) {
      // Если планируем потратить больше чем есть, уменьшаем покупки
      _reducePurchasesToFitBudget(stockData, amount);
      totalToSpend = stockData.fold(0.0, (sum, data) => sum + data['buyCost']);
    }

    remainingAmount = amount - totalToSpend;

    // Шаг 4: Если остались деньги после первоначального распределения
    if (remainingAmount > 0) {
      _distributeRemainingBudget(stockData, remainingAmount, targetAmounts);
    }

    // Шаг 5: Записываем результаты
    for (var data in stockData) {
      final int index = data['index'];
      final int lotsToBuy = data['lotsToBuy'];
      final double buyCost = data['buyCost'];
      final double totalCost = data['existingCost'] + buyCost;
      final double percentage = (totalCost / totalPortfolioValue) * 100;

      _allocations[index] = StockAllocation(
        stock: _allocations[index].stock,
        lots: lotsToBuy,
        existingLots: _allocations[index].existingLots,
        totalCost: buyCost,
        percentage: percentage,
        existingCost: data['existingCost'],
        existingPercentage:
            (data['existingCost'] / currentPortfolioValue * 100),
      );
    }
  }

  void _reducePurchasesToFitBudget(
    List<Map<String, dynamic>> stockData,
    double availableBudget,
  ) {
    // Сортируем по приоритету уменьшения покупок (последние добавленные - первые)
    // Акции с наименьшим отклонением от цели после покупки - первыми на уменьшение
    stockData.sort((a, b) {
      final double devA = a['deviationAfterBuy'];
      final double devB = b['deviationAfterBuy'];
      // Меньшее положительное отклонение (ближе к цели) - уменьшаем первыми
      return devA.compareTo(devB);
    });

    double totalSpent = stockData.fold(
      0.0,
      (sum, data) => sum + data['buyCost'],
    );

    while (totalSpent > availableBudget && totalSpent > 0) {
      bool reduced = false;

      for (var data in stockData) {
        if (data['lotsToBuy'] > 0) {
          // Уменьшаем покупку на 1 лот
          data['lotsToBuy'] = data['lotsToBuy'] - 1;
          data['buyCost'] = data['lotsToBuy'] * data['lotCost'];
          data['totalCostAfterBuy'] = data['existingCost'] + data['buyCost'];
          data['deviationAfterBuy'] =
              data['targetAmount'] - data['totalCostAfterBuy'];

          totalSpent = stockData.fold(0.0, (sum, d) => sum + d['buyCost']);
          reduced = true;

          if (totalSpent <= availableBudget) {
            break;
          }
        }
      }

      if (!reduced) {
        break; // Больше нечего уменьшать
      }
    }
  }

  void _distributeRemainingBudget(
    List<Map<String, dynamic>> stockData,
    double remainingAmount,
    List<double> targetAmounts,
  ) {
    // Находим акции, которые все еще недоинвестированы после первоначальной покупки
    List<Map<String, dynamic>> underInvestedStocks = [];

    for (var data in stockData) {
      double deviation = data['deviationAfterBuy'];
      // Акция недоинвестирована если отклонение больше 0
      if (deviation > 0) {
        underInvestedStocks.add(data);
      }
    }

    bool distributed = true;
    while (remainingAmount > 0 &&
        distributed &&
        underInvestedStocks.isNotEmpty) {
      distributed = false;

      // Сортируем по отклонению (самые недоинвестированные - первые)
      underInvestedStocks.sort(
        (a, b) => b['deviationAfterBuy'].compareTo(a['deviationAfterBuy']),
      );

      // Создаем копию списка для итерации
      final List<Map<String, dynamic>> stocksToProcess = List.from(
        underInvestedStocks,
      );

      for (var data in stocksToProcess) {
        double lotCost = data['lotCost'];
        double deviation = data['deviationAfterBuy'];

        // Проверяем можно ли купить лот
        if (lotCost <= remainingAmount && deviation >= lotCost * 0.5) {
          // Покупаем лот
          data['lotsToBuy'] = data['lotsToBuy'] + 1;
          data['buyCost'] = data['lotsToBuy'] * data['lotCost'];
          data['totalCostAfterBuy'] = data['existingCost'] + data['buyCost'];
          data['deviationAfterBuy'] =
              data['targetAmount'] - data['totalCostAfterBuy'];

          remainingAmount -= lotCost;
          distributed = true;

          // Обновляем список недоинвестированных
          if (data['deviationAfterBuy'] <= 0) {
            underInvestedStocks.remove(data);
          }

          if (remainingAmount <= 0) break;
        }
      }

      // Если не смогли ничего купить, выходим
      if (!distributed) {
        break;
      }
    }

    // Если все еще остались деньги, распределяем равномерно среди всех
    if (remainingAmount > 0) {
      _distributeEvenlyAllStocks(stockData, remainingAmount);
    }
  }

  void _distributeEvenlyAllStocks(
    List<Map<String, dynamic>> stockData,
    double remainingAmount,
  ) {
    // Создаем список всех акций, которые можно докупить
    List<Map<String, dynamic>> availableStocks = [];

    for (var data in stockData) {
      double lotCost = data['lotCost'];

      // Акция доступна если хватает денег на лот
      if (lotCost <= remainingAmount) {
        availableStocks.add(data);
      }
    }

    bool distributed = true;
    while (remainingAmount > 0 && distributed && availableStocks.isNotEmpty) {
      distributed = false;

      // Сортируем по количеству лотов для покупки (меньше - первыми)
      availableStocks.sort((a, b) => a['lotsToBuy'].compareTo(b['lotsToBuy']));

      // Создаем копию списка для итерации
      final List<Map<String, dynamic>> stocksToProcess = List.from(
        availableStocks,
      );

      for (var data in stocksToProcess) {
        double lotCost = data['lotCost'];

        if (lotCost <= remainingAmount) {
          // Покупаем лот
          data['lotsToBuy'] = data['lotsToBuy'] + 1;
          data['buyCost'] = data['lotsToBuy'] * data['lotCost'];
          data['totalCostAfterBuy'] = data['existingCost'] + data['buyCost'];

          remainingAmount -= lotCost;
          distributed = true;

          // Обновляем список доступных
          if (lotCost > remainingAmount) {
            availableStocks.remove(data);
          }

          if (remainingAmount <= 0) break;
        } else {
          availableStocks.remove(data);
        }
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  void _onShareChanged(int index) {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Покупка акций'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchStockPrices,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _stocks.isEmpty
            ? const Center(
                child: Text(
                  'Нет данных для отображения',
                  style: TextStyle(fontSize: 16),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 18),
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

                    // Индикатор загрузки SMA
                    if (_isLoadingSma)
                      Card(
                        margin: const EdgeInsets.all(8.0),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Загрузка данных SMA200...',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Переключатель SMA корректировки
                    // Card(
                    //   margin: const EdgeInsets.all(8.0),
                    //   child: Padding(
                    //     padding: const EdgeInsets.all(12.0),
                    //     child: Column(
                    //       crossAxisAlignment: CrossAxisAlignment.start,
                    //       children: [
                    //         Row(
                    //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //           children: [
                    //             Expanded(
                    //               child: Column(
                    //                 crossAxisAlignment:
                    //                     CrossAxisAlignment.start,
                    //                 children: [
                    //                   const Text(
                    //                     'Корректировка по SMA200',
                    //                     style: TextStyle(
                    //                       fontWeight: FontWeight.w600,
                    //                     ),
                    //                   ),
                    //                 ],
                    //               ),
                    //             ),
                    //             Switch(
                    //               value: _useSmaAdjustment,
                    //               onChanged: _stocksWithSma > 0
                    //                   ? (value) => _toggleSmaAdjustment()
                    //                   : null,
                    //               activeColor: Colors.blue,
                    //             ),
                    //           ],
                    //         ),
                    //       ],
                    //     ),
                    //   ),
                    // ),
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

                    ExistingSharesInput(
                      stocks: _stocks,
                      controllers: _existingSharesControllers,
                      onRebalance: _rebalancePortfolio,
                      onChanged: _onShareChanged,
                      targetPercentages: _calculateTargetPercentages(),
                    ),

                    if (_showAllocation)
                      AllocationResults(
                        allocations: _allocations,
                        amount: double.tryParse(_amountController.text) ?? 0,
                        remaining:
                            (double.tryParse(_amountController.text) ?? 0) -
                            _allocations.fold(
                              0.0,
                              (sum, allocation) => sum + allocation.totalCost,
                            ),
                        useSmaAdjustment: _useSmaAdjustment,
                        targetPercentages: _calculateTargetPercentages(),
                      ),

                    AdaptiveStocksGrid(stocks: _stocks),
                  ],
                ),
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
