import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class AppApi extends GetConnect {
  final _storage = GetStorage();
  @override
  void onInit() {
    httpClient.baseUrl = "https://wb-api.dits.ly/api/mobile";
    httpClient.timeout = const Duration(seconds: 60);
    httpClient.addRequestModifier<Object?>((request) {
      request.headers['Accept'] = 'application/json';
      request.headers['Content-Type'] = 'application/json';
      return request;
    });
    super.onInit();
  }

  Future requestOtp() async {
    var res = await post("/auth/login", {
      'email': _storage.read('email'),
      'password': _storage.read('password'),
    });
    return parse(res);
  }

  Future verifyOp(String code) async {
    var res = await post("/auth/verify", {
      'email': _storage.read('email'),
      'otp': code,
    });
    return parse(res);
  }

  Future sendResetPasswordOtp(String email) async {
    var res = await post("/reset-password/send-otp", {'email': email});
    return parse(res);
  }

  Future resetPassword(String email, String password, String code) async {
    var res = await post("/reset-password/verify", {
      'email': email,
      'otp': code,
      'password': password,
    });
    return parse(res);
  }

  dynamic parse(Response response) {
    if (kDebugMode) {
      print('Response: ${response.bodyString}');
    }
    if (response.isOk) {
      return response.body;
    }
    if (response.body == null) {
      throw AppApiException(
        message: 'msg_no_internet'.tr,
        code: APICode.noInternet,
      );
    } else if (response.statusCode == 422) {
      throw AppApiException(
        message:
            response.body is Map
                ? response.body['message']
                : response.statusText,
        code: APICode.validation,
      );
    } else if (response.statusCode == 401) {
      throw AppApiException(
        message: response.statusText ?? 'msg_unauthorized'.tr,
        code: APICode.unAuthorized,
      );
    } else if (response.statusCode == 409) {
      throw AppApiException(
        message: response.body['message'] ?? 'unauthorized',
        code: APICode.unknown,
      );
    } else {
      throw AppApiException(
        message: (response.statusText ?? 'Server side error'),
        code: APICode.unknown,
      );
    }
  }
}

enum APICode {
  noInternet,
  validation,
  notFound,
  noContent,
  server,
  unknown,
  unAuthorized,
}

class AppApiException implements Exception {
  final String message;
  final APICode code;

  AppApiException({required this.message, required this.code});
}
