import 'package:enough_mail/enough_mail.dart';
import 'package:get/get.dart';

class ComposeController extends GetxController {
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
}
