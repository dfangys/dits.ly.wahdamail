import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:wahda_bank/views/view/controllers/inbox_controller.dart';
import 'package:wahda_bank/views/view/new_message/widgets/to_text_field.dart';

class NewMessageScreen extends StatelessWidget {
  NewMessageScreen({super.key});
  final TextEditingController subjectController = TextEditingController();
  final HtmlEditorController htmlController = HtmlEditorController();
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
              IconButton(
                onPressed: () => showCupertinoDialog(
                    context: context, builder: createDialog),
                icon: const Icon(
                  CupertinoIcons.paperplane,
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
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    HtmlEditor(
                      controller: htmlController,
                      htmlEditorOptions: const HtmlEditorOptions(
                        hint: "Your message here...",
                      ),
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
