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

  // Кэш больше не нужен для сложных расчетов, но оставим для хранения простой цели
  List<double>? _cachedTargetPercentages;

  @override
  void initState() {
    super.initState();
    // Инициализация контроллеров для ввода существующих акций
    for (int i = 0; i < StockService.stocksInfo.length; i++) {
      _existingSharesControllers.add(TextEditingController(text: ''));
    }
    _fetchStockPrices();
  }

  Future<void> _fetchStockPrices() async {
    setState(() {
      _isLoading = true;
      _isLoadingSma = true; // Загружаем SMA просто для отображения на карточках
      _error = '';
      _showAllocation = false;
      _cachedTargetPercentages = null;
    });

    try {
      final loadedStocks = await _stockService.fetchStockPrices();

      setState(() {
        _stocks = loadedStocks;
        _isLoading = false;
        _isLoadingSma = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
        _isLoadingSma = false;
        _error = 'Ошибка загрузки: $error';
      });
    }
  }

  /// АЛГОРИТМ: равное распределение между всеми акциями
  /// АЛГОРИТМ: равное распределение между всеми акциями
  List<double> _calculateTargetPercentages() {
    if (_stocks.isEmpty) return [];

    if (_cachedTargetPercentages != null) {
      return _cachedTargetPercentages!;
    }

    final int stockCount = _stocks.length;
    print('\n=== РАСЧЕТ ЦЕЛЕВЫХ ДОЛЕЙ (Равное распределение) ===');

    final double equalTarget = 100.0 / stockCount;
    List<double> targets = List.filled(stockCount, equalTarget);

    // Нормализуем, чтобы сумма была ровно 100.00
    targets = _normalizeToSum(targets, 100.0);

    _cachedTargetPercentages = targets;

    print('Количество акций: $stockCount');
    for (int i = 0; i < _stocks.length; i++) {
      print('${_stocks[i].secId}: ${targets[i].toStringAsFixed(2)}%');
    }

    return targets;
  }

  /// Нормализация с округлением до 2 знаков (было 1)
  List<double> _normalizeToSum(List<double> weights, double targetSum) {
    final int count = weights.length;
    double currentSum = weights.fold(0.0, (a, b) => a + b);
    if (currentSum.abs() < 0.0001) return List.filled(count, 0.0);

    double factor = targetSum / currentSum;
    List<double> normalized = weights.map((w) => w * factor).toList();

    // Округляем до 2 знаков после запятой (было 1)
    List<double> result = normalized
        .map((w) => double.parse(w.toStringAsFixed(2)))
        .toList();

    double roundedSum = result.fold(0.0, (a, b) => a + b);
    double diff = targetSum - roundedSum;

    // Распределяем погрешность по всем акциям, а не только первой
    if (diff.abs() > 0.001) {
      int idx = 0;
      double remaining = diff;
      while (remaining.abs() > 0.005 && idx < count) {
        double adjustment = remaining > 0 ? 0.01 : -0.01;
        result[idx] = double.parse(
          (result[idx] + adjustment).toStringAsFixed(2),
        );
        remaining -= adjustment;
        idx++;
      }
    }

    return result;
  }

  void _rebalancePortfolio() {
    if (_stocks.isEmpty) {
      _showSnackBar('Нет данных об акциях для ребалансировки', Colors.red);
      return;
    }

    // Считаем текущую стоимость портфеля
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

    // Получаем целевые доли (равные)
    _cachedTargetPercentages = null; // Сбрасываем кэш на всякий случай
    final List<double> targetPercentages = _calculateTargetPercentages();

    // Обновляем поля ввода: сколько акций должно быть, чтобы доля была равной
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

    _showSnackBar('Портфель ребалансирован до равных долей', Colors.green);
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

    // Подготовка структуры результатов
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

    // ЗАПУСК ИТЕРАТИВНОГО АЛГОРИТМА (Выравнивание до равной доли)
    _allocateIteratively(
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

  /// АЛГОРИТМ: Выравнивание долей
  /// Покупаем лот той акции, у которой текущая доля сильнее всего отстает от целевой (8.33%)
  void _allocateIteratively(
    double amountToSpend,
    List<double> sharePrices,
    List<double> targetPercentages,
    double currentPortfolioValue,
    double totalPortfolioValue,
    List<double> existingCosts,
  ) {
    List<int> lotsToBuy = List.filled(_stocks.length, 0);
    List<double> currentValues = List.from(existingCosts);

    double spent = 0.0;

    // Стоимость одного лота для каждой акции
    List<double> lotCosts = [];
    for (int i = 0; i < _stocks.length; i++) {
      lotCosts.add(sharePrices[i] * _stocks[i].lotSize);
    }

    int safetyCounter = 0;
    const int maxIterations = 10000;

    while (spent < amountToSpend && safetyCounter < maxIterations) {
      safetyCounter++;

      int bestIndex = -1;
      double maxDeficit = -double.infinity;

      for (int i = 0; i < _stocks.length; i++) {
        double lotCost = lotCosts[i];

        // Если не хватает денег даже на 1 лот, пропускаем
        if (spent + lotCost > amountToSpend + 0.01) continue;

        // Считаем, какой будет доля акции, если мы купим этот лот
        double futureTotalPortfolio = currentPortfolioValue + spent + lotCost;
        double futureTarget =
            (targetPercentages[i] / 100) * futureTotalPortfolio;
        double futureCurrent = currentValues[i] + lotCost;

        // Дефицит: насколько текущая доля меньше целевой
        // (Чем меньше futureCurrent по сравнению с futureTarget, тем выше дефицит)
        double deficit = futureTarget - futureCurrent;

        if (deficit > maxDeficit) {
          maxDeficit = deficit;
          bestIndex = i;
        }
      }

      // Если не нашли, что купить (деньги закончились или дефицита нет), выходим
      if (bestIndex == -1) break;

      // Покупаем лот
      double buyLotCost = lotCosts[bestIndex];
      lotsToBuy[bestIndex]++;
      currentValues[bestIndex] += buyLotCost;
      spent += buyLotCost;
    }

    print('Аллокация завершена. Потрачено: $spent из $amountToSpend');

    // Записываем результаты
    for (int i = 0; i < _stocks.length; i++) {
      final double buyCost = lotsToBuy[i] * lotCosts[i];
      final double totalCost = existingCosts[i] + buyCost;

      _allocations[i] = StockAllocation(
        stock: _allocations[i].stock,
        lots: lotsToBuy[i],
        existingLots: _allocations[i].existingLots,
        totalCost: buyCost,
        percentage: (totalCost / (currentPortfolioValue + spent)) * 100,
        existingCost: existingCosts[i],
        existingPercentage: (existingCosts[i] / currentPortfolioValue * 100),
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
        title: const Text('Покупка акций (Равные доли)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchStockPrices,
            tooltip: 'Обновить цены',
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
                    if (_isLoadingSma) const LinearProgressIndicator(),
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
                                labelText: 'Сумма пополнения (₽)',
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
                                child: const Text(
                                  'Рассчитать докупку',
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
                        // Передаем false, чтобы виджет не пытался применять логику SMA
                        useSmaAdjustment: false,
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
