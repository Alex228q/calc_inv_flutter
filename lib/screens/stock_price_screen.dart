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

  // Кэш для целевых процентов
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

  /// Получение целевых процентов из StockService
  List<double> _calculateTargetPercentages() {
    if (_stocks.isEmpty) return [];

    if (_cachedTargetPercentages != null) {
      return _cachedTargetPercentages!;
    }

    print('\n=== РАСЧЕТ ЦЕЛЕВЫХ ДОЛЕЙ (Индивидуальное распределение) ===');

    final List<double> targets = StockService.getTargetPercentages();

    print('Целевые доли:');
    for (int i = 0; i < _stocks.length && i < targets.length; i++) {
      print('${_stocks[i].secId}: ${targets[i].toStringAsFixed(2)}%');
    }

    _cachedTargetPercentages = targets;
    return targets;
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

    // Рассчитываем, сколько акций должно быть для достижения целевых долей
    for (int i = 0; i < _stocks.length; i++) {
      final stock = _stocks[i];
      final double targetValue =
          (targetPercentages[i] / 100) * currentPortfolioValue;
      int targetShares = (targetValue / stock.lastPrice).round();
      targetShares = targetShares < 0 ? 0 : targetShares;

      // Учитываем размер лота
      int targetLots = (targetShares / stock.lotSize).ceil();
      targetShares = targetLots * stock.lotSize;

      _existingSharesControllers[i].text = targetShares.toString();
    }

    setState(() {
      _showAllocation = false;
      _cachedTargetPercentages = null;
    });

    _showSnackBar('Портфель ребалансирован до целевых долей', Colors.green);
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

        if (spent + lotCost > amountToSpend + 0.01) continue;

        double futureTotalPortfolio = currentPortfolioValue + spent + lotCost;
        double futureTarget =
            (targetPercentages[i] / 100) * futureTotalPortfolio;
        double futureCurrent = currentValues[i] + lotCost;

        double deficit = futureTarget - futureCurrent;

        if (deficit > maxDeficit) {
          maxDeficit = deficit;
          bestIndex = i;
        }
      }

      if (bestIndex == -1) break;

      double buyLotCost = lotCosts[bestIndex];
      lotsToBuy[bestIndex]++;
      currentValues[bestIndex] += buyLotCost;
      spent += buyLotCost;
    }

    print('Аллокация завершена. Потрачено: $spent из $amountToSpend');

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
        title: const Text('Индивидуальные доли'),
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
