import 'package:flutter_test/flutter_test.dart';

// Legacy imports (should resolve via deprecated shims)
import 'package:wahda_bank/views/box/mailbox_view.dart' as legacy_mailbox;
import 'package:wahda_bank/views/box/enhanced_mailbox_view.dart'
    as legacy_enhanced;
import 'package:wahda_bank/views/view/showmessage/show_message.dart'
    as legacy_detail;
import 'package:wahda_bank/views/view/showmessage/show_message_pager.dart'
    as legacy_pager;

void main() {
  test('P31 shim imports expose legacy symbols (type visibility)', () {
    // Referencing types via TypeMatcher ensures symbols are exported and usable
    const TypeMatcher<legacy_mailbox.MailBoxView>();
    const TypeMatcher<legacy_enhanced.EnhancedMailboxView>();
    const TypeMatcher<legacy_detail.ShowMessage>();
    const TypeMatcher<legacy_pager.ShowMessagePager>();

    // If we reached here, compilation/linking of the types succeeded.
    expect(true, isTrue);
  });
}
