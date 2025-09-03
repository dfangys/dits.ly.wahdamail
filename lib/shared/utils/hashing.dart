class Hashing {
  Hashing._();
  // Simple, stable DJB2 hash for strings (non-cryptographic; used for telemetry redaction)
  static int djb2(String input) {
    int hash = 5381;
    for (int i = 0; i < input.length; i++) {
      hash = ((hash << 5) + hash) + input.codeUnitAt(i);
    }
    return hash & 0x7fffffff; // keep positive
  }
}
