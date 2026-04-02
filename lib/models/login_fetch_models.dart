import 'course.dart';

class LoginFetchProcessResult {
  const LoginFetchProcessResult({
    required this.courses,
    required this.cookieSnapshotCaptured,
  });

  final List<Course> courses;
  final bool cookieSnapshotCaptured;
}

class LoginFetchChunkState {
  final StringBuffer _buffer = StringBuffer();
  int expectedChunks = 0;
  int receivedChunks = 0;

  void reset() {
    _buffer.clear();
    expectedChunks = 0;
    receivedChunks = 0;
  }

  void begin(int totalChunks) {
    reset();
    expectedChunks = totalChunks;
  }

  void appendChunk(String chunk) {
    _buffer.write(chunk);
    receivedChunks++;
  }

  String takePayload() => _buffer.toString();
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
