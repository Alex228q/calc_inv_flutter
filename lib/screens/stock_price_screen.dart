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
  bool _isLoadingSma = false;
  int _stocksWithSma = 0;

  // Кэшируем целевые проценты
  List<double>? _cachedTargetPercentages;

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
      _cachedTargetPercentages = null;
    });

    try {
      final loadedStocks = await _stockService.fetchStockPrices();
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

  /// УЛУЧШЕННЫЙ АЛГОРИТМ РАСЧЕТА
  List<double> _calculateTargetPercentages() {
    if (_stocks.isEmpty) return [];
    if (_cachedTargetPercentages != null) return _cachedTargetPercentages!;

    final int stockCount = _stocks.length;
    final double basePercentage = 100.0 / stockCount;

    print('\n=== РАСЧЕТ ЦЕЛЕВЫХ ДОЛЕЙ (ПЛАВНАЯ КОРРЕКТИРОВКА) ===');
    print('Базовая доля: ${basePercentage.toStringAsFixed(1)}%');

    // Параметры алгоритма
    const double maxAdjustment = 3.0; // Максимальное отклонение от базы (±3%)
    const double deviationCap =
        20.0; // Отклонение, при котором достигается максимум корректировки

    List<double> rawWeights = [];

    for (final stock in _stocks) {
      double deviation = stock.deviationFromSma ?? 0;

      // Линейное отображение отклонения на корректировку.
      // deviation: -20 -> adjustment: +3 (покупаем больше)
      // deviation:   0 -> adjustment:  0 (нейтрально)
      // deviation: +20 -> adjustment: -3 (покупаем меньше)

      double adjustment = 0;

      if (deviation != 0) {
        // Нормализуем отклонение в диапазон от -1 до 1
        double normalizedDev = (deviation / deviationCap).clamp(-1.0, 1.0);

        // Инвертируем: если цена упала (deviation < 0), мы хотим купить больше (adjustment > 0)
        adjustment = -normalizedDev * maxAdjustment;
      }

      double target = basePercentage + adjustment;

      // Защита от отрицательных или нулевых весов (оставляем минимум 0.5%)
      target = target.clamp(0.5, basePercentage + maxAdjustment + 1.0);

      rawWeights.add(target);

      print(
        '${stock.shortName}: откл ${deviation.toStringAsFixed(1)}% -> коррекция ${adjustment.toStringAsFixed(2)}% -> цель ${target.toStringAsFixed(2)}%',
      );
    }

    // Нормализация суммы ровно до 100%
    List<double> normalized = _normalizeToSum(rawWeights, 100.0);

    _cachedTargetPercentages = normalized;
    return normalized;
  }

  List<double> _normalizeToSum(List<double> weights, double targetSum) {
    final int count = weights.length;
    double currentSum = weights.fold(0.0, (a, b) => a + b);

    if (currentSum.abs() < 0.0001) {
      return List.filled(count, targetSum / count);
    }

    // Пропорциональное масштабирование
    double factor = targetSum / currentSum;
    List<double> normalized = weights.map((w) => w * factor).toList();

    // Округление и корректировка остатка
    List<double> result = normalized
        .map((w) => double.parse(w.toStringAsFixed(1)))
        .toList();
    double roundedSum = result.fold(0.0, (a, b) => a + b);
    double diff = targetSum - roundedSum;

    // Распределяем разницу (0.1 или -0.1) по элементам с наибольшей дробной частью
    if (diff.abs() > 0.001) {
      // Создаем список индексов, сортированных по тому, насколько сильно "обрезало" округление
      var indices = List.generate(count, (i) => i);
      indices.sort((a, b) {
        double fracA = normalized[a] - result[a];
        double fracB = normalized[b] - result[b];
        // Если нужно добавить (diff > 0), берем тех, у кого дробная часть больше
        // Если нужно убавить (diff < 0), берем тех, у кого дробная часть меньше (или отрицательная)
        return (diff > 0 ? fracB - fracA : fracA - fracB).toInt();
      });

      int idx = 0;
      while (diff.abs() > 0.001 && idx < count) {
        int i = indices[idx];
        double change = diff > 0 ? 0.1 : -0.1;
        if (result[i] + change > 0) {
          // Защита от отрицательных значений
          result[i] += change;
          diff -= change;
        }
        idx++;
      }
    }

    print('--- НОРМАЛИЗАЦИЯ ---');
    print(
      'Сумма итоговая: ${result.fold(0.0, (a, b) => a + b).toStringAsFixed(1)}%',
    );

    return result;
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

    _cachedTargetPercentages = null;
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
      _cachedTargetPercentages = null;
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
      existingShares.add(int.tryParse(_existingSharesControllers[i].text) ?? 0);
    }

    double currentPortfolioValue = 0;
    final List<double> sharePrices = [];
    final List<double> existingCosts = [];

    for (int i = 0; i < _stocks.length; i++) {
      final stock = _stocks[i];
      final double cost = existingShares[i] * stock.lastPrice;
      sharePrices.add(stock.lastPrice);
      existingCosts.add(cost);
      currentPortfolioValue += cost;
    }

    final double totalPortfolioValue = currentPortfolioValue + amount;
    _cachedTargetPercentages = null;
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
    final List<double> targetAmounts = [];
    for (int i = 0; i < _stocks.length; i++) {
      targetAmounts.add((targetPercentages[i] / 100) * totalPortfolioValue);
    }

    final List<Map<String, dynamic>> stockData = [];
    double totalToSpend = 0;

    for (int i = 0; i < _stocks.length; i++) {
      final stock = _stocks[i];
      final double lotCost = sharePrices[i] * stock.lotSize;
      final double targetAmount = targetAmounts[i];
      final double existingCost = existingCosts[i];
      final double neededAmount = targetAmount - existingCost;

      int lotsToBuy = 0;
      if (neededAmount > 0) {
        lotsToBuy = (neededAmount / lotCost).floor();
      }

      double buyCost = lotsToBuy * lotCost;

      stockData.add({
        'index': i,
        'stock': stock,
        'lotCost': lotCost,
        'targetAmount': targetAmount,
        'existingCost': existingCost,
        'lotsToBuy': lotsToBuy,
        'buyCost': buyCost,
        'deviationAfterBuy': targetAmount - (existingCost + buyCost),
      });

      totalToSpend += buyCost;
    }

    double remainingAmount = amount;

    // Если превысили бюджет, урезаем
    if (totalToSpend > amount) {
      _reducePurchasesToFitBudget(stockData, amount);
      totalToSpend = stockData.fold(0.0, (sum, data) => sum + data['buyCost']);
    }

    remainingAmount = amount - totalToSpend;

    // Распределяем остаток
    if (remainingAmount > 0) {
      _distributeRemainingBudget(stockData, remainingAmount);
    }

    // Финальное сохранение результатов
    for (var data in stockData) {
      final int index = data['index'];
      final int lotsToBuy = data['lotsToBuy'];
      final double buyCost = data['buyCost'];
      final double totalCost = data['existingCost'] + buyCost;

      _allocations[index] = StockAllocation(
        stock: _allocations[index].stock,
        lots: lotsToBuy,
        existingLots: _allocations[index].existingLots,
        totalCost: buyCost,
        percentage: (totalCost / totalPortfolioValue) * 100,
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
    // Сортируем по "важности" покупки: у кого отклонение от цели самое отрицательное (сильный недолет), того режем последним
    stockData.sort(
      (a, b) => b['deviationAfterBuy'].compareTo(a['deviationAfterBuy']),
    );

    double totalSpent = stockData.fold(
      0.0,
      (sum, data) => sum + data['buyCost'],
    );

    while (totalSpent > availableBudget) {
      bool reduced = false;
      // Идем с конца (у кого избыток или наименьший дефицит) и урезаем
      for (int i = stockData.length - 1; i >= 0; i--) {
        var data = stockData[i];
        if (data['lotsToBuy'] > 0) {
          data['lotsToBuy']--;
          double lotCost = data['lotCost'];
          data['buyCost'] -= lotCost;
          data['deviationAfterBuy'] += lotCost;
          totalSpent -= lotCost;
          reduced = true;

          if (totalSpent <= availableBudget) break;
        }
      }
      if (!reduced) break;
    }
  }

  void _distributeRemainingBudget(
    List<Map<String, dynamic>> stockData,
    double remainingAmount,
  ) {
    // Сортируем по дефициту: у кого отклонение самое большое (сильный недолет), тому добавляем первым
    stockData.sort(
      (a, b) => b['deviationAfterBuy'].compareTo(a['deviationAfterBuy']),
    );

    bool changed = true;
    while (remainingAmount > 0 && changed) {
      changed = false;
      for (var data in stockData) {
        double lotCost = data['lotCost'];
        if (lotCost <= remainingAmount) {
          data['lotsToBuy']++;
          data['buyCost'] += lotCost;
          data['deviationAfterBuy'] -= lotCost;
          remainingAmount -= lotCost;
          changed = true;
          break; // После покупки пересчитываем сортировку, так как приоритеты могли поменяться
        }
      }
      // Обновляем сортировку после прохода
      stockData.sort(
        (a, b) => b['deviationAfterBuy'].compareTo(a['deviationAfterBuy']),
      );
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  void _onShareChanged(int index) {
    setState(() {
      _cachedTargetPercentages = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<double> currentTargets = _calculateTargetPercentages();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Покупка акций (SMA)'),
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
            ? const Center(child: Text('Нет данных для отображения'))
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
                    if (_isLoadingSma)
                      const Card(
                        margin: EdgeInsets.all(8.0),
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text('Загрузка данных SMA200...'),
                              ),
                            ],
                          ),
                        ),
                      ),
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
                      targetPercentages: currentTargets,
                    ),
                    if (_showAllocation)
                      AllocationResults(
                        allocations: _allocations,
                        amount: double.tryParse(_amountController.text) ?? 0,
                        remaining:
                            (double.tryParse(_amountController.text) ?? 0) -
                            _allocations.fold(
                              0.0,
                              (sum, a) => sum + a.totalCost,
                            ),
                        useSmaAdjustment: true,
                        targetPercentages: currentTargets,
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
