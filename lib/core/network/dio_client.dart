import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../constants/app_constants.dart';

class DioClient {
  static Dio? _dio;

  static Dio get instance {
    _dio ??= Dio(
      BaseOptions(
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    return _dio!;
  }

  static Dio getNewsClient() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    return dio;
  }

  static Dio getUnsplashClient() {
    final accessKey = dotenv.env['UNSPLASH_ACCESS_KEY'] ?? 'demo_key';
    final dio = Dio(
      BaseOptions(
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Client-ID $accessKey',
        },
      ),
    );

    return dio;
  }

  static void addInterceptor(Interceptor interceptor) {
    instance.interceptors.add(interceptor);
  }

  static void removeInterceptor(Interceptor interceptor) {
    instance.interceptors.remove(interceptor);
  }
}

