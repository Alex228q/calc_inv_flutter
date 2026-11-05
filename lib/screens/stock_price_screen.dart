import 'package:flutter/material.dart';
import '../core/input_parsers.dart';
import '../data/stock_catalog.dart';
import '../domain/portfolio_calculator.dart';
import '../models/stock.dart';
import '../models/stock_allocation.dart';
import '../services/stock_service.dart';
import '../widgets/allocation_results.dart';
import '../widgets/amount_input_card.dart';
import '../widgets/existing_shares_input.dart';
import '../widgets/message_banner.dart';
import '../widgets/stocks_grid.dart';

class StockPriceScreen extends StatefulWidget {
  const StockPriceScreen({super.key});

  @override
  State<StockPriceScreen> createState() => _StockPriceScreenState();
}

class _StockPriceScreenState extends State<StockPriceScreen> {
  final _stockService = StockService();
  final _amountController = TextEditingController();

  /// Контроллеры по тикеру: введённые количества переживают обновление цен,
  /// даже если часть бумаг не загрузилась.
  final Map<String, TextEditingController> _shareControllers = {
    for (final c in stockCatalog) c.ticker: TextEditingController(),
  };

  List<Stock> _stocks = const [];
  List<double> _targets = const [];
  AllocationResult? _result;
  bool _isLoading = true;
  String? _error;

  List<TextEditingController> get _stockControllers => [
    for (final s in _stocks) _shareControllers[s.secId]!,
  ];

  List<int> get _existingShares => [
    for (final c in _stockControllers) parseShares(c.text),
  ];

  @override
  void initState() {
    super.initState();
    _loadStocks();
  }

  Future<void> _loadStocks() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
    });

    try {
      final stocks = await _stockService.fetchStocks();
      if (!mounted) return;
      setState(() {
        _stocks = stocks;
        _targets = PortfolioCalculator.normalizedTargets(stocks);
        _isLoading = false;
        if (stocks.isEmpty) _error = 'Не удалось загрузить данные об акциях';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Ошибка загрузки: $e';
      });
    }
  }

  void _rebalance() {
    final value = PortfolioCalculator.portfolioValue(_stocks, _existingShares);
    if (value <= 0) {
      _showSnackBar('Введите имеющиеся акции для ребалансировки', Colors.red);
      return;
    }

    final rebalanced = PortfolioCalculator.rebalancedShares(
      stocks: _stocks,
      targets: _targets,
      portfolioValue: value,
    );
    final controllers = _stockControllers;
    for (var i = 0; i < controllers.length; i++) {
      controllers[i].text = rebalanced[i].toString();
    }

    setState(() => _result = null);
    _showSnackBar('Портфель ребалансирован до целевых долей', Colors.green);
  }

  void _calculate() {
    final amount = parseAmount(_amountController.text);
    if (amount == null || amount <= 0) {
      _showSnackBar('Введите корректную сумму для расчета', Colors.red);
      return;
    }
    if (_stocks.isEmpty) {
      _showSnackBar('Нет данных об акциях для расчета', Colors.red);
      return;
    }

    final result = PortfolioCalculator.allocate(
      stocks: _stocks,
      existingShares: _existingShares,
      targets: _targets,
      amount: amount,
    );
    setState(() => _result = result);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  void dispose() {
    _amountController.dispose();
    for (final c in _shareControllers.values) {
      c.dispose();
    }
    _stockService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Распределение'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadStocks,
            tooltip: 'Обновить цены',
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_stocks.isEmpty) {
      return _ErrorView(
        message: _error ?? 'Нет данных для отображения',
        onRetry: _loadStocks,
      );
    }

    final isPartial = _stocks.length < stockCatalog.length;
    final bannerText =
        _error ??
        (isPartial
            ? 'Загружено ${_stocks.length} из ${stockCatalog.length} акций. '
                  'Расчёт учитывает только загруженные.'
            : null);

    final result = _result;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        children: [
          if (bannerText != null) MessageBanner(text: bannerText),
          AmountInputCard(
            controller: _amountController,
            onCalculate: _calculate,
          ),
          ExistingSharesInput(
            stocks: _stocks,
            controllers: _stockControllers,
            targetPercentages: _targets,
            onRebalance: _rebalance,
          ),
          if (result != null) AllocationResults(result: result),
          AdaptiveStocksGrid(stocks: _stocks),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}
