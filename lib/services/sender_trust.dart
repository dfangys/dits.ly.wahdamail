import 'package:get_storage/get_storage.dart';

class SenderTrustService {
  SenderTrustService._();
  static final instance = SenderTrustService._();

  static const _kBox = 'sender_trust';
  static const _kKeyPrefix = 'trust_sender_';

  GetStorage? _box;

  Future<void> init() async {
    _box ??= GetStorage(_kBox);
    if (!GetStorage().hasData(_kBox)) {
      // Ensure storage is initialized
      await GetStorage.init(_kBox);
      _box = GetStorage(_kBox);
    }
  }

  String _norm(String emailOrDomain) {
    return emailOrDomain.trim().toLowerCase();
  }

  Future<void> trustSender(String emailOrDomain, {bool trusted = true}) async {
    await init();
    final key = '$_kKeyPrefix${_norm(emailOrDomain)}';
    await _box!.write(key, trusted);
  }

  bool isTrusted(String emailOrDomain) {
    final key = '$_kKeyPrefix${_norm(emailOrDomain)}';
    return (_box ?? GetStorage(_kBox)).read(key) ?? false;
  }
}

