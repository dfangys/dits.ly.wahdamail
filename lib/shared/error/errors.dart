/// Shared error taxonomy (minimal for infra gateways)
class GatewayException implements Exception {
  final String code; // e.g., network_error, auth_error, rate_limited
  final String message;
  GatewayException(this.code, this.message);
  @override
  String toString() => 'GatewayException($code): $message';
}
