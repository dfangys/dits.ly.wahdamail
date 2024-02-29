import 'dart:async';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/widgets/mail_tile.dart';

class DraftView extends StatefulWidget {
  const DraftView({super.key});

  @override
  State<DraftView> createState() => _DraftViewState();
}

class _DraftViewState extends State<DraftView> {
  final StreamController<List<MimeMessage>> _streamController =
      StreamController<List<MimeMessage>>.broadcast();
  final MailService service = MailService.instance;
  late Mailbox mailbox;
  @override
  void initState() {
    service.client.selectMailboxByFlag(MailboxFlag.drafts).then((box) {
      mailbox = box;
      fetchMail();
    });
    super.initState();
  }

  List<MimeMessage> emails = [];

  int page = 1;

  Future fetchMail() async {
    try {
      mailbox = await service.client.selectMailboxByFlag(MailboxFlag.drafts);
      int maxExist = mailbox.messagesExists;
      while (emails.length < maxExist) {
        MessageSequence sequence = MessageSequence.fromPage(page, 10, maxExist);
        List<MimeMessage> fetched = await queue(sequence);
        emails.addAll(fetched);
        _streamController.add(emails);
      }
    } catch (e) {
      Get.snackbar('Error', e.toString());
      if (emails.isEmpty) _streamController.addError(e);
    }
  }

  Future<List<MimeMessage>> queue(MessageSequence sequence) async {
    return await service.client.fetchMessageSequence(
      sequence,
      fetchPreference: FetchPreference.full,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('drafts'.tr),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          emails.clear();
          fetchMail();
        },
        child: StreamBuilder<List<MimeMessage>>(
          stream: _streamController.stream,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  return MailTile(
                    onTap: () {},
                    message: snapshot.data![index],
                    mailBox: mailbox,
                  );
                },
              );
            } else if (snapshot.hasError) {
              return Center(
                child: Text('Error: ${snapshot.error}'),
              );
            }
            return const Center(
              child: CircularProgressIndicator(),
            );
          },
        ),
      ),
    );
  }
}
