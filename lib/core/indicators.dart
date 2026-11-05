/// Простая скользящая средняя по последним [period] значениям.
/// Возвращает null, если данных меньше периода.
double? simpleMovingAverage(List<double> values, int period) {
  if (period <= 0 || values.length < period) return null;
  final window = values.sublist(values.length - period);
  return window.fold<double>(0, (sum, v) => sum + v) / period;
}
