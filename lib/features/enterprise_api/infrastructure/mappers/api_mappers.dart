import 'package:wahda_bank/features/enterprise_api/domain/entities/account_profile.dart'
    as dom;
import 'package:wahda_bank/features/enterprise_api/domain/entities/contact.dart'
    as dom;
import 'package:wahda_bank/features/enterprise_api/domain/entities/signature.dart'
    as dom;
import 'package:wahda_bank/features/enterprise_api/domain/value_objects/token.dart'
    as dom;
import 'package:wahda_bank/features/enterprise_api/domain/value_objects/user_id.dart';
import 'package:wahda_bank/features/enterprise_api/infrastructure/gateways/rest_gateway.dart';

class ApiMappers {
  static dom.AccountProfile toDomainAccount(AccountDto dto) =>
      dom.AccountProfile(
        userId: UserId(dto.userId),
        email: dto.email,
        displayName: dto.displayName,
      );

  static dom.Contact toDomainContact(ContactDto dto) =>
      dom.Contact(id: dto.id, name: dto.name, email: dto.email);

  static dom.Signature toDomainSignature(SignatureDto dto) => dom.Signature(
    id: dto.id,
    contentHtml: dto.contentHtml,
    isDefault: dto.isDefault,
  );

  static SignatureDto fromDomainSignature(dom.Signature s) => SignatureDto(
    id: s.id,
    contentHtml: s.contentHtml,
    isDefault: s.isDefault,
  );

  static dom.Token toDomainToken(TokenDto dto) => dom.Token(
    accessToken: dto.accessToken,
    refreshToken: dto.refreshToken,
    expiresAt: DateTime.fromMillisecondsSinceEpoch(dto.expiresAtEpochMs),
  );
}
