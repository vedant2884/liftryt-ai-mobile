import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/providers.dart';
import 'models.dart';

/// Mirrors `frontend/src/api/chat.ts` and `chatStream.ts` — the existing
/// backend/OpenRouter integration, never a second AI client. The
/// OpenRouter key never enters this app; every call here is a plain
/// authenticated request to our own backend.
class CoachApi {
  final Dio _dio;

  const CoachApi(this._dio);

  // A coach reply isn't a simple CRUD round trip: assembling context runs
  // several embedding searches (CPU-bound — slow on Render's free-tier
  // compute, slower still right after a cold start before the model's
  // warmed up), and a tool-calling turn means two sequential LLM calls, not
  // one. The default 30s receiveTimeout genuinely isn't enough headroom for
  // that pipeline; the "Thinking..." indicator already sets the right
  // expectation, so a longer wait here doesn't cost anything in UX.
  static const _replyTimeout = Duration(seconds: 90);

  Future<List<ChatSession>> fetchSessions() async {
    try {
      final res = await _dio.get<List<dynamic>>('/chat/sessions');
      return res.data!.map((e) => ChatSession.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<ChatSession> createSession() async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/chat/sessions');
      return ChatSession.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<ChatMessage>> fetchMessages(String sessionId) async {
    try {
      final res = await _dio.get<List<dynamic>>('/chat/sessions/$sessionId/messages');
      return res.data!.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Streams one coach reply as SSE events — mirrors
  /// `frontend/src/api/chatStream.ts`'s event shapes exactly:
  /// `{"type": "start", "user_message": {...}}`,
  /// `{"type": "delta", "content": "..."}`,
  /// `{"type": "tool_result", "tool_name", "arguments", "result"}`,
  /// `{"type": "done", "assistant_message": {...}}`, or
  /// `{"type": "error", "detail": "..."}`. Cancel via [cancelToken] for the
  /// Stop-generation control — Dio surfaces that as a DioException with
  /// `type == DioExceptionType.cancel`, which callers should treat as an
  /// intentional stop, not a failure (same as the web app's AbortSignal
  /// handling in CoachPage.tsx).
  Stream<Map<String, dynamic>> sendMessageStream(
    String sessionId,
    String content, {
    CancelToken? cancelToken,
  }) async* {
    final Response<ResponseBody> res;
    try {
      res = await _dio.post<ResponseBody>(
        '/chat/sessions/$sessionId/messages/stream',
        data: {'content': content},
        options: Options(
          responseType: ResponseType.stream,
          sendTimeout: _replyTimeout,
          receiveTimeout: _replyTimeout,
        ),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
    yield* _parseSseStream(res.data!.stream);
  }

  Future<ChatMessage> requestWeeklyCheckin(String sessionId) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/chat/sessions/$sessionId/weekly-checkin',
        options: Options(sendTimeout: _replyTimeout, receiveTimeout: _replyTimeout),
      );
      return ChatMessage.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

/// Splits the raw SSE byte stream on blank-line-terminated events and
/// JSON-decodes each `data: ` line. Decodes via `.transform(utf8.decoder)`
/// (a real stream transformer, not a per-chunk `utf8.decode` call) so a
/// multi-byte UTF-8 character — routine for the coach's Hindi/Marathi
/// Devanagari replies — that happens to land split across two network
/// chunks gets reassembled correctly instead of corrupted or throwing.
///
/// `.cast<List<int>>()` (not just a `Stream<List<int>>`-typed parameter)
/// is required here: Dio's stream is concretely `Stream<Uint8List>` at
/// runtime, and Dart generics are reified — declaring this function's
/// parameter as the supertype `Stream<List<int>>` only satisfies the
/// static analyzer, while `.transform()` at runtime still checks against
/// the stream OBJECT's actual type parameter (Uint8List), throwing
/// "Utf8Decoder is not a subtype of StreamTransformer&lt;Uint8List, String&gt;"
/// even though `flutter analyze` sees nothing wrong. `.cast<List<int>>()`
/// wraps it in a real `CastStream` whose runtime type parameter genuinely
/// is `List<int>`, which Utf8Decoder (StreamTransformer&lt;List&lt;int&gt;,
/// String&gt;) actually matches.
Stream<Map<String, dynamic>> _parseSseStream(Stream<List<int>> byteStream) async* {
  var buffer = '';
  await for (final textChunk in byteStream.cast<List<int>>().transform(utf8.decoder)) {
    buffer += textChunk;
    while (buffer.contains('\n\n')) {
      final splitAt = buffer.indexOf('\n\n');
      final rawEvent = buffer.substring(0, splitAt);
      buffer = buffer.substring(splitAt + 2);
      for (final line in rawEvent.split('\n')) {
        if (line.startsWith('data: ')) {
          yield jsonDecode(line.substring('data: '.length)) as Map<String, dynamic>;
        }
      }
    }
  }
}

final coachApiProvider = Provider((ref) => CoachApi(ref.watch(dioProvider)));
