/// Base failure class for Clean Architecture domain layers in SONORA.
abstract class Failure {
  const Failure(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() =>
      '$runtimeType: $message${cause != null ? ' ($cause)' : ''}';
}

/// Failure occurring during audio playback, decoding, or audio session management.
class AudioFailure extends Failure {
  const AudioFailure(super.message, [super.cause]);
}

/// Failure occurring during SQLite/Drift database operations or file I/O.
class StorageFailure extends Failure {
  const StorageFailure(super.message, [super.cause]);
}

/// Failure occurring when media permission (audio storage/read) is denied.
class PermissionFailure extends Failure {
  const PermissionFailure(super.message, [super.cause]);
}
