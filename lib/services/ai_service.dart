import 'dart:typed_data';

import '../core/network/api_client.dart';
import '../core/network/network_exception.dart';
import '../models/ai_waste.dart';

/// REST access to the AI waste recognition backend.
///
/// The prediction model is exposed outside the `/api` namespace for the
/// health/info endpoints and under `/api/v1` for the prediction itself:
///  - `POST /api/v1/predict` (multipart, field key `image`)
///  - `GET  /health`
///  - `GET  /model/info`
class AiService {
  AiService._();
  static final AiService instance = AiService._();

  /// Classify a waste photo and return the recognition result.
  ///
  /// [bytes] is the raw JPEG/PNG payload; [filename] is used as the upload
  /// filename (extension matters for the backend's image decoding).
  Future<AiWaste> predict(Uint8List bytes, {required String filename}) async {
    final response = await ApiClient.instance.multipart(
      '/v1/predict',
      field: 'image',
      bytes: bytes,
      filename: filename,
    );
    final data = ApiClient.instance.decode(response, fallback: 'Failed to classify the image');
    final map = (data as Map?)?.cast<String, dynamic>();
    if (map == null) {
      throw const ApiException('The AI model returned an empty response.');
    }
    
    // Check if wrapped in 'aiwaste' key or top-level payload
    final payload = (map['aiwaste'] is Map)
        ? (map['aiwaste'] as Map).cast<String, dynamic>()
        : map;

    return AiWaste.fromJson(payload);
  }

  /// Check whether the server, database, and AI model are alive.
  ///
  /// Returns the raw payload (field names vary by backend version) — callers
  /// read it defensively.
  Future<Map<String, dynamic>> health() async {
    final response = await ApiClient.instance.getRoot('/health');
    final data = ApiClient.instance.decode(response, fallback: 'Health check failed');
    return (data as Map?)?.cast<String, dynamic>() ?? const {};
  }

  /// Fetch the AI model details (backbone, classes, inputs).
  ///
  /// Returns the raw payload — callers read it defensively since the schema
  /// is backend-defined.
  Future<Map<String, dynamic>> modelInfo() async {
    final response = await ApiClient.instance.getRoot('/model/info');
    final data = ApiClient.instance.decode(response, fallback: 'Failed to load model info');
    return (data as Map?)?.cast<String, dynamic>() ?? const {};
  }
}
