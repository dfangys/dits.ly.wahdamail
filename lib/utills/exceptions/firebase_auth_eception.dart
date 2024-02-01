class WFirebaseAuthException implements Exception {
  final String code;
  WFirebaseAuthException(this.code);
  String get message {
    switch (code) {
      case 'email-already in use':
        return "The email address is already registered. Please use avdifferent email.";
      case 'invalid-email':
        return "The email address provided is invalid. Please enter a valid email.";
      case 'weak-password':
        return "The password is too weak. Please choose a stronger password.";
      case 'user-disabled':
        return "This user account has been disabled. Please contact support for assistance.";
      case 'user-not-found':
        return "Invalid login details. User not found";
      case 'wrong-password':
        return "Incorrect password. please check your password and try again.";
      case 'invalid-vaerification-code':
        return "Invlaid verification code. please enter a valid code.";
      case 'invalid-vaerification-id':
        return "Invlaid verification ID. Please request a new verificattion code.";
      case 'quota-exceeded':
        return "Quota exceeded. Please try again later";
      case 'email-already-exists':
        return "The email adrress is already exists. pLease us ea different email.";
      case 'provider-already-linked':
        return "The account is already linked with another provider.";
      default:
        return 'An unexpected error occoured. Please try again.';
    }
  }
}
