import 'package:hai_schedule/models/course.dart';

class LoginFetchProcessResult {
  const LoginFetchProcessResult({
    required this.courses,
    required this.cookieSnapshotCaptured,
  });

  final List<Course> courses;
  final bool cookieSnapshotCaptured;
}

class LoginFetchChunkState {
  final Map<int, String> _chunks = <int, String>{};
  String? activeRequestId;
  int expectedChunks = 0;

  int get receivedChunks => _chunks.length;
  bool get isComplete =>
      expectedChunks > 0 &&
      _chunks.length == expectedChunks &&
      List<int>.generate(
        expectedChunks,
        (index) => index,
      ).every(_chunks.containsKey);

  void arm(String requestId) {
    _chunks.clear();
    expectedChunks = 0;
    activeRequestId = requestId;
  }

  void reset() {
    _chunks.clear();
    expectedChunks = 0;
    activeRequestId = null;
  }

  void begin({required String requestId, required int totalChunks}) {
    _chunks.clear();
    expectedChunks = totalChunks;
    activeRequestId = requestId;
  }

  bool appendChunk({required int index, required String chunk}) {
    if (index < 0 || expectedChunks <= 0 || index >= expectedChunks) {
      return false;
    }
    _chunks.putIfAbsent(index, () => chunk);
    return true;
  }

  String takePayload() {
    final buffer = StringBuffer();
    for (var index = 0; index < expectedChunks; index++) {
      final chunk = _chunks[index];
      if (chunk == null) {
        throw StateError('Missing chunk $index for request $activeRequestId');
      }
      buffer.write(chunk);
    }
    return buffer.toString();
  }
}

class LoginAutofillResult {
  const LoginAutofillResult({
    required this.usernameFilled,
    required this.passwordFilled,
    required this.submitted,
    required this.verificationRequired,
  });

  final bool usernameFilled;
  final bool passwordFilled;
  final bool submitted;
  final bool verificationRequired;
}

class LoginFetchException implements Exception {
  const LoginFetchException(this.message);

  final String message;

  @override
  String toString() => message;
}
