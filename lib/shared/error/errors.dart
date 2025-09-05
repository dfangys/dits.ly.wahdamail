/// Shared error taxonomy for cross-layer use (infra + domain mapping).
/// Keep free of Flutter imports.
sealed class AppError implements Exception {
  final String message;
  final Object? cause;
  const AppError(this.message, [this.cause]);
  @override
  String toString() => '${Object.hash(runtimeType, message)}: $message';
}

class AuthError extends AppError {
  const AuthError(String message, [Object? cause]) : super(message, cause);
}

class TransientNetworkError extends AppError {
  const TransientNetworkError(String message, [Object? cause])
    : super(message, cause);
}

class PermanentProtocolError extends AppError {
  const PermanentProtocolError(String message, [Object? cause])
    : super(message, cause);
}

class RateLimitError extends AppError {
  const RateLimitError(String message, [Object? cause]) : super(message, cause);
}

class StorageCorruptionError extends AppError {
  const StorageCorruptionError(String message, [Object? cause])
    : super(message, cause);
}

class RenderingError extends AppError {
  const RenderingError(String message, [Object? cause]) : super(message, cause);
}

// P8: Security/Crypto errors
class CryptoError extends AppError {
  const CryptoError(String message, [Object? cause]) : super(message, cause);
}

class DecryptionError extends CryptoError {
  const DecryptionError(String message, [Object? cause])
    : super(message, cause);
}

class SignatureInvalidError extends CryptoError {
  const SignatureInvalidError(String message, [Object? cause])
    : super(message, cause);
}

class KeyNotFoundError extends CryptoError {
  const KeyNotFoundError(String message, [Object? cause])
    : super(message, cause);
}
