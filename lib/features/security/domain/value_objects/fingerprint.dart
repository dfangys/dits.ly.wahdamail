class Fingerprint {
  final String hex;
  const Fingerprint(this.hex) : assert(hex != '');
  @override
  String toString() => hex;
  @override
  bool operator ==(Object other) =>
      other is Fingerprint && other.hex.toLowerCase() == hex.toLowerCase();
  @override
  int get hashCode => hex.toLowerCase().hashCode;
}
