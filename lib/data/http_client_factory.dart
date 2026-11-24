import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// HTTP-клиент для MOEX.
/// Принимает самоподписанный сертификат (антивирус/прокси) только для iss.moex.com.
http.Client createMoexHttpClient() {
  final inner = HttpClient()
    ..badCertificateCallback = (X509Certificate cert, String host, int port) =>
        host == 'iss.moex.com';
  return IOClient(inner);
}

