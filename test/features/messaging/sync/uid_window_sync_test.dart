import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/messaging/infrastructure/datasources/local_store.dart';
import 'package:wahda_bank/features/messaging/infrastructure/sync/uid_window_sync.dart';
import 'package:wahda_bank/features/messaging/infrastructure/gateways/imap_gateway.dart';

class _FakeGateway implements ImapGateway {
  @override
  Future<List<int>> downloadAttachment({
    required String accountId,
    required String folderId,
    required String messageUid,
    required String partId,
  }) => throw UnimplementedError();
  @override
  Future<BodyDTO> fetchBody({
    required String accountId,
    required String folderId,
    required String messageUid,
  }) => throw UnimplementedError();
  @override
  Future<List<HeaderDTO>> fetchHeaders({
    required String accountId,
    required String folderId,
    int limit = 50,
    int offset = 0,
  }) => throw UnimplementedError();
  @override
  Stream<ImapEvent> idleStream({
    required String accountId,
    required String folderId,
  }) => const Stream.empty();
  @override
  Future<List<AttachmentDTO>> listAttachments({
    required String accountId,
    required String folderId,
    required String messageUid,
  }) => throw UnimplementedError();
  @override
  Future<List<HeaderDTO>> searchHeaders({
    required String accountId,
    required String folderId,
    required dynamic q,
  }) => throw UnimplementedError();
}

void main() {
  test('UID window resumes from highest-seen without duplicates', () async {
    final store = InMemoryLocalStore();
    final gw = _FakeGateway();
    final sync = UidWindowSync(gateway: gw, store: store, defaultWindow: 100);

    // Initially none seen
    var ranges = await sync.nextWindows(folderId: 'INBOX', remoteMaxUid: 350);
    expect(ranges.length, 4); // 1-100, 101-200, 201-300, 301-350

    // Record progress and resume
    await sync.recordProgress(folderId: 'INBOX', fetchedMaxUid: 220);
    ranges = await sync.nextWindows(folderId: 'INBOX', remoteMaxUid: 350);
    expect(ranges.first.start, 221);
    expect(ranges.last.end, 350);
  });
}
