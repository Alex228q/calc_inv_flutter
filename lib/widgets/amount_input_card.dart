import 'package:flutter/material.dart';

class AmountInputCard extends StatelessWidget {
  const AmountInputCard({
    super.key,
    required this.controller,
    required this.onCalculate,
  });

  final TextEditingController controller;
  final VoidCallback onCalculate;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Сумма пополнения (₽)',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => onCalculate(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onCalculate,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
    );
  }
}
