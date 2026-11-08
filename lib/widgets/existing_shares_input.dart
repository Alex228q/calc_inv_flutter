import 'package:flutter/material.dart';
import '../core/formatters.dart';
import '../core/input_parsers.dart';
import '../domain/portfolio_calculator.dart';
import '../models/stock.dart';
import 'share_input_tile.dart';

class ExistingSharesInput extends StatelessWidget {
  const ExistingSharesInput({
    super.key,
    required this.stocks,
    required this.controllers,
    required this.targetPercentages,
    required this.onRebalance,
  });

  /// [controllers] и [targetPercentages] — в том же порядке, что и [stocks].
  final List<Stock> stocks;
  final List<TextEditingController> controllers;
  final List<double> targetPercentages;
  final VoidCallback onRebalance;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        // Перестраиваемся при любом изменении полей — колбэк onChanged не нужен.
        child: ListenableBuilder(
          listenable: Listenable.merge(controllers),
          builder: (context, _) {
            final shares = [for (final c in controllers) parseShares(c.text)];
            final portfolioValue = PortfolioCalculator.portfolioValue(
              stocks,
              shares,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(onRebalance: onRebalance),
                if (portfolioValue > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Текущая стоимость портфеля: ${formatRub(portfolioValue)}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 46,
                  runSpacing: 10,
                  children: [
                    for (var i = 0; i < stocks.length; i++)
                      ShareInputTile(
                        stock: stocks[i],
                        controller: controllers[i],
                        currentPercentage: portfolioValue > 0
                            ? shares[i] *
                                  stocks[i].lastPrice /
                                  portfolioValue *
                                  100
                            : 0,
                        targetPercentage: targetPercentages[i],
                        portfolioIsEmpty: portfolioValue <= 0,
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onRebalance});

  final VoidCallback onRebalance;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        const Text(
          'Уже имеющиеся акции (в штуках):',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        ElevatedButton.icon(
          onPressed: onRebalance,
          icon: const Icon(Icons.autorenew, size: 20),
          label: const Text('Ребалансировка'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
