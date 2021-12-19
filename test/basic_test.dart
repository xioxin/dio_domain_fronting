import 'dart:io';

import 'package:dio/adapter.dart';
import 'package:dio/dio.dart';
import 'package:dio_domain_fronting/src/dio_domain_fronting.dart';
import 'package:test/test.dart';

void main() {
  test('auto', () async {
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

    await dio.get('https://example.com/',
        options: Options(followRedirects: false));
  });

  test('manual', () async {
    final dio = Dio();
    final domainFronting = DomainFronting(
      manual: true,
    );

    // Ignore certificate errors
    (dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate =
        (HttpClient client) {
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) {
        return true;
      };
    };

    // Add the plug-ins after the others have been added to ensure the correct order of execution
    domainFronting.bind(dio);

    // A switch that can be used to disable the function.
    // domainFronting.enable = false;

    await dio.get('https://example.com/',
        options: DomainFronting.ip('93.184.216.34'));
  });
}
