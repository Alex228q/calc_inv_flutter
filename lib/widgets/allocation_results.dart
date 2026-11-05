import 'package:flutter/material.dart';
import '../core/formatters.dart';
import '../models/stock_allocation.dart';
import 'allocation_row.dart';

class AllocationResults extends StatelessWidget {
  const AllocationResults({super.key, required this.result});

  final AllocationResult result;

  @override
  Widget build(BuildContext context) {
    final purchases = result.purchases;

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Результаты распределения:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Среднее отклонение от целевых долей: '
              '${formatPercent(result.averageDeviation)}',
              style: TextStyle(
                fontSize: 12,
                color: result.averageDeviation < 5
                    ? Colors.green
                    : Colors.orange,
              ),
            ),
            const SizedBox(height: 16),
            if (purchases.isEmpty)
              const _NothingToBuy()
            else
              for (final allocation in purchases)
                AllocationRow(allocation: allocation),
            const SizedBox(height: 16),
            Divider(color: Colors.grey[300]),
            const SizedBox(height: 8),
            _SummaryRow(
              label: 'Текущий портфель:',
              value: formatRub(result.existingValue),
              valueStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
            _SummaryRow(
              label: 'Всего купить лотов:',
              value: '${result.totalLots}',
              valueStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            _SummaryRow(
              label: 'Общая стоимость покупки:',
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              value: formatRub(result.spent),
              valueStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            _SummaryRow(
              label: 'Остаток:',
              value: formatRub(result.remaining),
              valueStyle: TextStyle(
                color: result.remaining > 0 ? Colors.orange : Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NothingToBuy extends StatelessWidget {
  const _NothingToBuy();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        'Не нужно докупать акции - портфель уже сбалансирован',
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.valueStyle,
    this.labelStyle,
  });

  final String label;
  final String value;
  final TextStyle valueStyle;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: labelStyle),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}
