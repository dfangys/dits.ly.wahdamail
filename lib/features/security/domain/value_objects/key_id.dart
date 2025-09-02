class KeyId {
  final String value;
  const KeyId(this.value) : assert(value != '');
  @override
  String toString() => value;
  @override
  bool operator ==(Object other) => other is KeyId && other.value == value;
  @override
  int get hashCode => value.hashCode;
}
