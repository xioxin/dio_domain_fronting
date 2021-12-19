# Dio Domain Fronting
A DomainFronting plugin for dio.

## Get started

### Add dependency

```yaml
dependencies:
  dio: ^4.0.0
  dio_domain_fronting: ^1.0.0
```

### Super simple to use

```dart
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

  final response = await dio.get('https://example.com/');
}

```
