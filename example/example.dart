import 'dart:io';
import 'package:dio/adapter.dart';
import 'package:dio/dio.dart';
import 'package:dio_domain_fronting/dio_domain_fronting.dart';

void main() async {
  final dio = Dio();

  final hosts = {
    'example.com': '93.184.216.34',
  };

  final domainFronting = DomainFronting(
    dnsLookup: (host) => hosts[host],
  );

  // Ignore certificate errors
  (dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate =
      (HttpClient client) {
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      return hosts.containsValue(host);
    };
  };

  // Add the plug-ins after the others have been added to ensure the correct order of execution
  domainFronting.bind(dio);

  // A switch that can be used to disable the function.
  // domainFronting.enable = false;

  final response = await dio.get('https://example.com/',
      options: Options(followRedirects: false));
  final regExp = RegExp(r'<title>(.*)<\/title>');
  print(regExp.firstMatch(response.toString())?.group(1));
}
