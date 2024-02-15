import 'package:enough_mail/enough_mail.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:wahda_bank/services/mail_service.dart';

class ComposeController extends GetxController {
  MailAccount account = MailService.instance.account;
  MailClient client = MailService.instance.client;

  RxList<MailAddress> toList = <MailAddress>[].obs;
  RxList<MailAddress> cclist = <MailAddress>[].obs;
  RxList<MailAddress> bcclist = <MailAddress>[].obs;

  RxBool isCcAndBccVisible = false.obs;

  void addTo(MailAddress mailAddress) {
    if (toList.isNotEmpty && toList[0] == mailAddress) return;
    if (GetUtils.isEmail(mailAddress.email)) toList.add(mailAddress);
  }

  void removeFromToList(int index) => toList.removeAt(index);

  void addToCC(MailAddress mailAddress) {
    if (cclist.isNotEmpty && cclist[0] == mailAddress) return;
    if (GetUtils.isEmail(mailAddress.email)) cclist.add(mailAddress);
  }

  void removeFromCcList(int index) => cclist.removeAt(index);

  void addToBcc(MailAddress mailAddress) {
    if (bcclist.isNotEmpty && bcclist[0] == mailAddress) return;
    if (GetUtils.isEmail(mailAddress.email)) bcclist.add(mailAddress);
  }

  void removeFromBccList(int index) => bcclist.removeAt(index);

  final storage = GetStorage();

  // Constant for the email address
  String get email => account.email;
  String get name => storage.read('accountName') ?? account.name;

  @override
  void onInit() {
    super.onInit();
  }
}
