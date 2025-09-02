class UserId {
  final String value;
  const UserId(this.value) : assert(value != '');

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) => other is UserId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
