class WFirebaseException implements Exception {
  final String code;
  WFirebaseException(this.code);
  String get message {
    switch (code) {
      case 'unknown':
        return "An unknown Firebase error occoured. Please try again.";
      case 'invalid-custom-token':
        return "The custom token formt is incorrect. Please check your custom token";
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
      case 'operation-not-allowed':
        return "This operation is not allowed.  contact support for assistance.";
      case 'email-already-exists':
        return "The email adrress is already exists. pLease us ea different email.";
      case 'provider-already-linked':
        return "The account is already linked with another provider.";
      case 'keychain-error':
        return "An keychain error occoured. Please check the keychain and try again.";
      case 'custom-token-mismatch':
        return "The custom token correspond a different audience";
      case 'internal-error':
        return "An internal authentication error occoured. Please try again later.";
      default:
        return 'An unexpected error occoured. Please try again.';
    }
  }
}
