import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'api_providers.dart';
import 'json_codec.dart';

class RiderDocumentRecord {
  const RiderDocumentRecord({
    required this.documentType,
    required this.status,
    this.createdAt,
  });

  factory RiderDocumentRecord.fromJson(Map<String, Object?> json) {
    return RiderDocumentRecord(
      documentType: jsonString(json['document_type']) ?? '',
      status: jsonString(json['status']) ?? '',
      createdAt: jsonDate(json['created_at']),
    );
  }

  final String documentType;
  final String status;
  final DateTime? createdAt;
}

class RiderDocumentsApi {
  RiderDocumentsApi(this._client);

  final ApiClient _client;

  Future<List<RiderDocumentRecord>> list() async {
    final Map<String, Object?> body = await _client.get('/v1/rider/documents');
    return jsonList(body['documents'])
        .map(
          (Object? item) => RiderDocumentRecord.fromJson(jsonObject(item)),
        )
        .toList(growable: false);
  }

  Future<RiderDocumentRecord> upload({
    required String documentType,
    required String filePath,
  }) async {
    final FormData form = FormData.fromMap(<String, Object?>{
      'document_type': documentType,
      'file': await MultipartFile.fromFile(filePath),
    });
    return RiderDocumentRecord.fromJson(
      await _client.postForm('/v1/rider/documents', data: form),
    );
  }
}

final riderDocumentsApiProvider = Provider<RiderDocumentsApi>((ref) {
  return RiderDocumentsApi(ref.watch(apiClientProvider));
});
