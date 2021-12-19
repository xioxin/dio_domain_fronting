import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';

typedef DomainFrontingDomainLookup = FutureOr<String?> Function(
    String hostname);

class DomainFronting {
  bool enable = true;

  late DomainFrontingDomainLookup? _dnsLookup;
  bool noIpSkip;
  bool manual;

  /// [dnsLookup]: Handle domain name resolution.
  ///
  /// [noIpSkip]: Skip DomainFronting if no ip is obtained,
  ///             otherwise an exception will be thrown.
  ///
  /// [manual]: Manual mode, you need to pass [DomainFronting.auto] or [DomainFronting.ip]
  ///          in the request options to enable it. Set to false to enable all requests by default
  DomainFronting({
    DomainFrontingDomainLookup? dnsLookup,
    this.noIpSkip = true,
    this.manual = false,
  }) {
    _dnsLookup = dnsLookup;
  }

  static Options auto([Options? options]) {
    if (options == null) {
      return Options(extra: {'domainFronting': true});
    }
    final extra = {...(options.extra ?? {}), 'domainFronting': true};
    return options.copyWith(extra: extra);
  }

  static Options ip(String ip, [Options? options]) {
    if (options == null) {
      return Options(extra: {'domainFronting': ip});
    }
    final extra = {...(options.extra ?? {}), 'domainFronting': ip};
    return options.copyWith(extra: extra);
  }

  Future<String?> lookup(String hostname) async {
    if (_dnsLookup == null) return null;
    return await _dnsLookup!(hostname);
  }

  /// To bind the plugin to dio, make sure to add this plugin last.
  void bind(Dio dio) {
    dio.interceptors.add(DomainFrontingInterceptorRequest(this));
    dio.interceptors.insert(0, DomainFrontingInterceptorResponse(dio, this));
  }
}

class DomainFrontingInterceptorResponse extends Interceptor {
  final DomainFronting df;
  final Dio dio;

  DomainFrontingInterceptorResponse(this.dio, this.df);

  @override
  void onResponse(
    Response e,
    ResponseInterceptorHandler handler,
  ) {
    if ((!df.enable) ||
        (!e.requestOptions.extra.containsKey('domainFrontingRawOptions'))) {
      handler.next(e);
      return;
    }
    final rawOptions = e.requestOptions.extra['domainFrontingRawOptions'];
    e.requestOptions = rawOptions;
    handler.next(e);
  }

  @override
  void onError(
    DioError err,
    ErrorInterceptorHandler handler,
  ) {
    if (err.response != null) {
      if ([301, 302].contains(err.response!.statusCode)) {
        final redirectCount = (err.requestOptions
                .extra['domainFrontingRawOptionsRedirectCount'] ??
            0);
        final location =
            err.response?.headers[HttpHeaders.locationHeader]?.first;
        if (location != null) {
          if (redirectCount <= 5) {
            final uri = err.requestOptions.uri.resolve(location);
            final request = err.requestOptions;

            final newRequest = request.copyWith(path: uri.path, extra: {
              ...request.extra,
              'domainFrontingRawOptionsRedirectCount': redirectCount + 1,
            });
            dio.fetch(newRequest).then((value) => handler.resolve(value));
            return;
          }
        }
      }
    }

    handler.next(err);
  }
}

class DomainFrontingInterceptorRequest extends Interceptor {
  final DomainFronting df;

  DomainFrontingInterceptorRequest(this.df);

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    if ((!df.enable) || options.uri.scheme.toLowerCase() != 'https') {
      handler.next(options);
      return;
    }

    final dynamic domainFronting =
        options.extra['domainFronting'] ?? (!df.manual);
    final host = options.uri.host;
    String? ip;

    if (domainFronting is bool) {
      if (domainFronting) {
        try {
          ip = await df.lookup(host);
        } catch (error, stackTrace) {
          final err = DioError(requestOptions: options, error: error);
          err.stackTrace = stackTrace;
          handler.reject(err, true);
          return;
        }
      } else {
        handler.next(options);
        return;
      }
    } else if (domainFronting is String) {
      ip = domainFronting;
    }

    if (ip == null) {
      if (df.noIpSkip) {
        handler.next(options);
        return;
      }
      final err = DioError(
          requestOptions: options,
          error: '[DomainFronting] Unable to get IP address');
      err.stackTrace = StackTrace.current;
      handler.reject(err, true);
      return;
    }

    final newUri = options.uri.replace(host: ip);
    final headers = {...options.headers, 'host': host};
    final extra = {...options.extra, 'domainFrontingRawOptions': options};
    handler.next(options.copyWith(
        path: newUri.toString(), headers: headers, extra: extra));
  }
}
