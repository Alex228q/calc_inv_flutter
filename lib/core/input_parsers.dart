/// Количество акций из текстового поля. Пустое/неверное/отрицательное → 0.
int parseShares(String text) {
  final value = int.tryParse(text.trim()) ?? 0;
  return value < 0 ? 0 : value;
}

/// Сумма из текстового поля. Понимает запятую и пробелы: "10 000,5".
double? parseAmount(String text) {
  return double.tryParse(text.trim().replaceAll(' ', '').replaceAll(',', '.'));
}
