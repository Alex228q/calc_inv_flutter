import 'package:flutter/material.dart';
import '../models/stock.dart';

class ExistingSharesInput extends StatefulWidget {
  final List<Stock> stocks;
  final List<TextEditingController> controllers;
  final VoidCallback onRebalance;
  final ValueChanged<int>? onChanged;

  const ExistingSharesInput({
    Key? key,
    required this.stocks,
    required this.controllers,
    required this.onRebalance,
    this.onChanged,
  }) : super(key: key);

  @override
  State<ExistingSharesInput> createState() => _ExistingSharesInputState();
}

class _ExistingSharesInputState extends State<ExistingSharesInput> {
  double _calculateCurrentPortfolioValue() {
    double currentPortfolioValue = 0;
    for (int i = 0; i < widget.stocks.length; i++) {
      final stock = widget.stocks[i];
      final existingShares = int.tryParse(widget.controllers[i].text) ?? 0;
      currentPortfolioValue += existingShares * stock.lastPrice;
    }
    return currentPortfolioValue;
  }

  Color _getExistingPercentageColor(double percentage, int stockCount) {
    final average = 100.0 / stockCount;
    final deviation = (percentage - average).abs();
    if (deviation < 5) return Colors.green;
    if (deviation < 15) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final currentPortfolioValue = _calculateCurrentPortfolioValue();

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 450) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Уже имеющиеся акции (в штуках):',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: widget.onRebalance,
                        icon: const Icon(Icons.autorenew, size: 20),
                        label: const Text('Ребалансировка'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  );
                } else {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Уже имеющиеся акции (в штуках):',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: widget.onRebalance,
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
              },
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

            Wrap(
              spacing: 16.0,
              runSpacing: 16.0,
              children: List.generate(widget.stocks.length, (index) {
                final stock = widget.stocks[index];
                final existingShares =
                    int.tryParse(widget.controllers[index].text) ?? 0;
                final double cost = existingShares * stock.lastPrice;
                final double percentage = currentPortfolioValue > 0
                    ? (cost / currentPortfolioValue * 100)
                    : 0;

                return SizedBox(
                  width: 154,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: widget.controllers[index],
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
                          if (widget.onChanged != null) {
                            widget.onChanged!(index);
                          }
                        },
                      ),

                      if (existingShares > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
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
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value: percentage / 100,
                                      backgroundColor: Colors.grey[200],
                                      color: _getExistingPercentageColor(
                                        percentage,
                                        widget.stocks.length,
                                      ),
                                      minHeight: 6,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${percentage.toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
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
}
