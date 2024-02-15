extension StringExtension on String {
  String ucFirst() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
