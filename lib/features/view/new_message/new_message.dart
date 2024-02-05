import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:wahda_bank/features/view/controllers/inbox_controller.dart';
import 'package:wahda_bank/features/view/new_message/widgets/to_text_field.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';

class NewMessageScreen extends StatelessWidget {
  NewMessageScreen({super.key});
  final TextEditingController subjectController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(InboxController());
    final user = controller.users[0];
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.medium(
            leading: IconButton(
                onPressed: () {}, icon: const Icon(CupertinoIcons.back)),
            title: Text(
              'New message',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            actions: [
              IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    CupertinoIcons.add,
                    color: Colors.green,
                  )),
              InkWell(
                onTap: () => showCupertinoDialog(
                    context: context, builder: createDialog),
                child: const ImageIcon(
                  AssetImage(WImages.sent),
                  color: Colors.green,
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  CupertinoIcons.ellipsis_vertical_circle,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('From'),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '"${user.name}" <${user.email}>',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge!
                                .apply(color: Colors.green),
                          )
                        ],
                      ),
                    ),
                    WToTextField(),
                    const SizedBox(
                      height: 10,
                    ),
                    const Text('Subject'),
                    Container(
                        height: 45,
                        padding: const EdgeInsets.only(left: 10, right: 10),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey)),
                        child: TextFormField(
                          controller: subjectController,
                          decoration: InputDecoration(
                              hintText: 'Message Subject',
                              hintStyle:
                                  TextStyle(color: Colors.grey.shade400)),
                        )),
                    const SizedBox(
                      height: 10,
                    ),
                    HtmlEditor(
                      controller: controller.controller,
                      htmlEditorOptions: const HtmlEditorOptions(
                          shouldEnsureVisible: true,
                          hint: 'Send with Mail',
                          spellCheck: true,
                          adjustHeightForKeyboard: false),
                    ),
                    Container(
                      height: 100,
                    )
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

Widget createDialog(BuildContext context) => CupertinoAlertDialog(
      actions: [
        CupertinoDialogAction(
          child: const Text('Save as draft'),
          onPressed: () {},
        ),
        CupertinoDialogAction(
          child: const Text('Request read reciept'),
          onPressed: () {},
        ),
        CupertinoDialogAction(
          child: const Text('Convert to plain text'),
          onPressed: () {},
        ),
        CupertinoDialogAction(
          child: const Text('Cancel'),
          onPressed: () {
            Get.back();
          },
        ),
      ],
    );
