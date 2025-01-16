// api_service.dart

import 'package:dio/dio.dart' as d_dio;
import 'package:dio/io.dart';
import 'package:get/get.dart';
import 'package:i_iwara/app/ui/widgets/MDToastWidget.dart';
import 'package:i_iwara/common/enums/media_enums.dart';
import 'package:i_iwara/i18n/strings.g.dart';

import '../../common/constants.dart';
import '../../utils/logger_utils.dart';
import 'auth_service.dart';
import 'message_service.dart';

class ApiService extends GetxService {
  static ApiService? _instance;
  late d_dio.Dio _dio;
  final AuthService _authService = Get.find<AuthService>();
  final MessageService _messageService = Get.find<MessageService>();
  final String _tag = 'ApiService';
  
  // 重试相关配置
  static const int maxRetries = 3;
  static const Duration baseRetryDelay = Duration(seconds: 1);

  // 构造函数返回的是同一个
  ApiService._();

  d_dio.Dio get dio => _dio;

  // 获取实例的静态方法
  static Future<ApiService> getInstance() async {
    _instance ??= await ApiService._().init();
    return _instance!;
  }

  Future<ApiService> init() async {
    _dio = d_dio.Dio(d_dio.BaseOptions(
      baseUrl: CommonConstants.iwaraApiBaseUrl,
      connectTimeout: const Duration(seconds: 45000),
      receiveTimeout: const Duration(seconds: 45000),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
        'Accept': 'application/json, text/plain, */*',
        'Connection': 'keep-alive',
        'Referer': CommonConstants.iwaraApiBaseUrl,
      },
    ));

    // 修改拦截器
    _dio.interceptors.add(d_dio.InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (CommonConstants.enableR18) {
          // do nothing
        } else {
          options.queryParameters = {
            ...options.queryParameters,
            'rating': MediaRating.GENERAL.value
          };
        }

        LogUtils.d(
            '请求: Method: ${options.method} Path: ${options.path} Params: ${options.queryParameters} Body: ${options.data}',
            _tag);
            
        // 请求预处理
        if (!await _preProcessRequest()) {
          return handler.reject(
            d_dio.DioException(
              requestOptions: options,
              error: 'Token refresh failed',
              type: d_dio.DioExceptionType.badResponse,
            ),
          );
        }
            
        // 如果有token，添加到请求头
        if (_authService.hasToken) {
          options.headers['Authorization'] = 'Bearer ${_authService.accessToken}';
        }
        
        return handler.next(options);
      },
      onError: (d_dio.DioException error, handler) async {
        // 处理网络错误
        if (error.type == d_dio.DioExceptionType.connectionTimeout ||
            error.type == d_dio.DioExceptionType.receiveTimeout ||
            error.type == d_dio.DioExceptionType.sendTimeout) {
          _handleNetworkError(error);
          return handler.next(error);
        }
        
        switch (error.response?.statusCode) {
          case 401: // Unauthorized - 未认证或认证已过期
            // 如果未登录，直接返回错误
            if (!_authService.hasToken) {
              _handleAuthError(error);
              return handler.next(error);
            }

            LogUtils.d('$_tag 遇到401错误（未认证或认证已过期），尝试刷新token');
            
            try {
              // 尝试刷新token
              final success = await _authService.refreshAccessToken();
              
              if (success) {
                // 重试原请求
                return handler.resolve(await _retryRequest(error.requestOptions));
              }
            } catch (e) {
              LogUtils.e('刷新token失败', tag: _tag, error: e);
            }
            _handleAuthError(error);
            break;
            
          case 403: // Forbidden - 已认证但无权限
            LogUtils.e('$_tag 遇到403错误（无权限访问）', error: error);
            _handleAuthError(error);
            break;
            
          default:
            _handleGeneralError(error);
        }
        
        return handler.next(error);
      },
    ));

    return this;
  }

  // 请求预处理
  Future<bool> _preProcessRequest() async {
    if (!_authService.hasToken) return true;
    
    // 检查token是否即将过期
    if (_authService.isAccessTokenExpired) {
      return await _authService.refreshAccessToken();
    }
    return true;
  }

  // 重试请求
  Future<d_dio.Response<T>> _retryRequest<T>(d_dio.RequestOptions options, {int currentRetry = 0}) async {
    try {
      final opts = d_dio.Options(
        method: options.method,
        headers: {
          ...options.headers,
          'Authorization': 'Bearer ${_authService.accessToken}'
        },
      );
      
      return await _dio.request<T>(
        options.path,
        options: opts,
        data: options.data,
        queryParameters: options.queryParameters,
      );
    } catch (e) {
      if (currentRetry < maxRetries - 1) {
        // 计算递增的重试延迟
        final delay = baseRetryDelay * (currentRetry + 1);
        await Future.delayed(delay);
        return _retryRequest(options, currentRetry: currentRetry + 1);
      }
      rethrow;
    }
  }

  // 处理认证错误
  void _handleAuthError(d_dio.DioException error) {
    switch (error.response?.statusCode) {
      case 401:
        if (!_authService.hasToken) {
          _messageService.showMessage(
            t.errors.pleaseLoginFirst,
            MDToastType.warning,
          );
        } else {
          _messageService.showMessage(
            t.errors.sessionExpired,
            MDToastType.warning,
          );
        }
        break;
      case 403:
        _messageService.showMessage(
          t.errors.noPermission,
          MDToastType.warning,
        );
        break;
    }
  }

  // 处理网络错误
  void _handleNetworkError(d_dio.DioException error) {
    _messageService.showMessage(
      t.errors.networkError,
      MDToastType.error,
    );
  }

  // 处理一般错误
  void _handleGeneralError(d_dio.DioException error) {
    final message = error.response?.data?['message'] ?? t.errors.unknownError;
    _messageService.showMessage(
      message,
      MDToastType.error,
    );
  }

  Future<d_dio.Response<T>> get<T>(String path,
      {Map<String, dynamic>? queryParameters,
      Map<String, dynamic>? headers}) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: d_dio.Options(headers: headers),
      );
    } on d_dio.DioException catch (e) {
      LogUtils.e('GET请求失败: ${e.message}, Path: $path', tag: _tag, error: e);
      rethrow;
    }
  }

  Future<d_dio.Response<T>> post<T>(String path,
      {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.post<T>(path,
          data: data, queryParameters: queryParameters);
    } on d_dio.DioException catch (e) {
      LogUtils.e('POST请求失败: ${e.message}', tag: _tag, error: e);
      rethrow;
    }
  }

  Future<d_dio.Response<T>> delete<T>(String path,
      {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.delete<T>(path, queryParameters: queryParameters);
    } on d_dio.DioException catch (e) {
      LogUtils.e('DELETE请求失败: ${e.message}', tag: _tag, error: e);
      rethrow;
    }
  }

  Future<d_dio.Response<T>> put<T>(String path,
      {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.put<T>(path,
          data: data, queryParameters: queryParameters);
    } on d_dio.DioException catch (e) {
      LogUtils.e('PUT请求失败: ${e.message}', tag: _tag, error: e);
      rethrow;
    }
  }

  // resetProxy
  void resetProxy() {
    _dio.httpClientAdapter = IOHttpClientAdapter();
  }

}
