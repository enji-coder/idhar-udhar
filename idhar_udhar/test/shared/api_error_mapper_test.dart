import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';

void main() {
  test('maps OTP_INVALID to a friendly message', () {
    final ApiException error = ApiErrorMapper.fromBody(
      <String, Object?>{
        'error': <String, Object?>{
          'code': 'OTP_INVALID',
          'message': 'secret sql boom',
          'request_id': 'req_1',
        },
      },
      statusCode: 401,
    );
    expect(error.code, 'OTP_INVALID');
    expect(error.message, 'Invalid OTP. Please try again.');
    expect(error.requestId, 'req_1');
    expect(error.message.toLowerCase().contains('sql'), isFalse);
  });

  test('strips unsafe backend text', () {
    final String message = ApiErrorMapper.userMessage(
      'UNKNOWN_CODE',
      'syntax error at relation public.orders',
    );
    expect(message, 'Something went wrong. Please try again.');
  });
}
