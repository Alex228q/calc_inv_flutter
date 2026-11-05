import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/formatters.dart';
import '../core/input_parsers.dart';
import '../models/stock.dart';

/// Поле ввода количества акций + карточка с текущей/целевой долей.
class ShareInputTile extends StatelessWidget {
  const ShareInputTile({
    super.key,
    required this.stock,
    required this.controller,
    required this.currentPercentage,
    required this.targetPercentage,
    required this.portfolioIsEmpty,
  });

  static const double width = 150;

  /// Бумага «перевешивает», если её доля больше целевой в столько раз.
  static const double rebalanceThreshold = 1.6;

  final Stock stock;
  final TextEditingController controller;
  final double currentPercentage;
  final double targetPercentage;
  final bool portfolioIsEmpty;

  @override
  Widget build(BuildContext context) {
    final shares = parseShares(controller.text);
    final needsRebalance =
        targetPercentage > 0 &&
        currentPercentage > targetPercentage * rebalanceThreshold;

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: stock.shortName,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
            ),
          ),
          if (shares > 0) ...[
            const SizedBox(height: 8),
            _HoldingInfo(
              cost: shares * stock.lastPrice,
              currentPercentage: currentPercentage,
              targetPercentage: targetPercentage,
              needsRebalance: needsRebalance,
            ),
          ] else if (portfolioIsEmpty) ...[
            const SizedBox(height: 8),
            _TargetOnlyInfo(targetPercentage: targetPercentage),
          ],
        ],
      ),
    );
  }
}

class _HoldingInfo extends StatelessWidget {
  const _HoldingInfo({
    required this.cost,
    required this.currentPercentage,
    required this.targetPercentage,
    required this.needsRebalance,
  });

  final double cost;
  final double currentPercentage;
  final double targetPercentage;
  final bool needsRebalance;

  /// Цвет по отклонению от ЦЕЛЕВОЙ доли (п.п.).
  Color get _currentColor {
    final deviation = (currentPercentage - targetPercentage).abs();
    if (deviation < 5) return Colors.green;
    if (deviation < 15) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: needsRebalance ? Colors.red[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: needsRebalance ? Colors.red[300]! : Colors.grey[300]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatRub(cost),
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (needsRebalance)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          _LabeledValue(
            label: 'Текущая:',
            value: formatPercent(currentPercentage),
            color: _currentColor,
          ),
          const SizedBox(height: 4),
          _LabeledValue(
            label: 'Целевая:',
            value: formatPercent(targetPercentage),
            color: Colors.blue[700]!,
          ),
          if (needsRebalance) ...[
            const SizedBox(height: 4),
            Text(
              '⚠️ Превышение в ${(currentPercentage / targetPercentage).toStringAsFixed(1)}x',
              style: TextStyle(
                fontSize: 10,
                color: Colors.red[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LabeledValue extends StatelessWidget {
  const _LabeledValue({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _TargetOnlyInfo extends StatelessWidget {
  const _TargetOnlyInfo({required this.targetPercentage});

  final double targetPercentage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Целевая доля:',
                style: TextStyle(fontSize: 11, color: Colors.blue[800]),
              ),
              Text(
                formatPercent(targetPercentage),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: targetPercentage / 100,
            backgroundColor: Colors.blue[100],
            color: Colors.blue[400],
            minHeight: 6,
          ),
        ],
      ),
    );
  }
}
