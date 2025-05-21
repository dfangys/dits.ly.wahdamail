import 'dart:async';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/widgets/mail_tile.dart';

import '../../widgets/empty_box.dart';

class DraftView extends StatefulWidget {
  const DraftView({super.key});

  @override
  State<DraftView> createState() => _DraftViewState();
}

class _DraftViewState extends State<DraftView> with SingleTickerProviderStateMixin {
  final StreamController<List<MimeMessage>> _streamController =
  StreamController<List<MimeMessage>>.broadcast();
  final MailService service = MailService.instance;
  late Mailbox mailbox;
  late AnimationController _animationController;

  @override
  void initState() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    service.client.selectMailboxByFlag(MailboxFlag.drafts).then((box) {
      mailbox = box;
      fetchMail();
      _animationController.forward();
    });
    super.initState();
  }

  List<MimeMessage> emails = [];
  int page = 1;
  bool _isLoading = false;

  Future fetchMail() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      emails.clear();
      page = 1;
      mailbox = await service.client.selectMailboxByFlag(MailboxFlag.drafts);
      int maxExist = mailbox.messagesExists;

      while (emails.length < maxExist) {
        MessageSequence sequence = MessageSequence.fromPage(page, 10, maxExist);
        List<MimeMessage> fetched = await queue(sequence);
        emails.addAll(fetched);
        emails = emails.sorted((a, b) => b.decodeDate()!.compareTo(a.decodeDate()!));
        _streamController.add(emails);
        page++;
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString(),
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
        borderRadius: 10,
        margin: const EdgeInsets.all(10),
        snackPosition: SnackPosition.BOTTOM,
      );
      if (emails.isEmpty) _streamController.addError(e);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<MimeMessage>> queue(MessageSequence sequence) async {
    return await service.client.fetchMessageSequence(
      sequence,
      fetchPreference: FetchPreference.envelope,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'drafts'.tr,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: theme.colorScheme.primary,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDarkMode
            ? Colors.black.withOpacity(0.7)
            : Colors.white.withOpacity(0.9),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          emails.clear();
          fetchMail();
        },
        color: theme.colorScheme.primary,
        backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.white,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDarkMode
                  ? [Colors.black, Colors.grey.shade900]
                  : [Colors.grey.shade50, Colors.white],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: StreamBuilder<List<MimeMessage>>(
              stream: _streamController.stream,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  if (snapshot.data!.isEmpty) {
                    return TAnimationLoaderWidget(
                      text: 'Whoops! Box is empty',
                      animation: 'assets/lottie/empty.json',
                      showAction: true,
                      actionText: 'try_again'.tr,
                      onActionPressed: () {
                        fetchMail();
                      },
                    );
                  }

                  return AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return ListView.builder(
                        itemCount: snapshot.data!.length,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          // Calculate staggered animation delay
                          final itemAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
                            CurvedAnimation(
                              parent: _animationController,
                              curve: Interval(
                                0.1 * (index / snapshot.data!.length),
                                0.6 + 0.4 * (index / snapshot.data!.length),
                                curve: Curves.easeOutQuad,
                              ),
                            ),
                          );

                          return Transform.translate(
                            offset: Offset(0, 50 * itemAnimation.value),
                            child: Opacity(
                              opacity: 1 - itemAnimation.value,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: MailTile(
                                  onTap: () {},
                                  message: snapshot.data![index],
                                  mailBox: mailbox,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                } else if (snapshot.hasError) {
                  return TAnimationLoaderWidget(
                    text: snapshot.error.toString(),
                    animation: 'assets/lottie/error.json',
                    showAction: true,
                    actionText: 'try_again'.tr,
                    onActionPressed: () {
                      fetchMail();
                    },
                  );
                }
                return const TAnimationLoaderWidget(
                  text: 'Loading...',
                  animation: 'assets/lottie/search.json',
                  showAction: false,
                );
              },
            ),
          ),
        ),
      ),
      floatingActionButton: AnimatedOpacity(
        opacity: _isLoading ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: FloatingActionButton(
          onPressed: () => fetchMail(),
          backgroundColor: theme.colorScheme.primary,
          child: const Icon(Icons.refresh, color: Colors.white),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _streamController.close();
    _animationController.dispose();
    super.dispose();
  }
}
