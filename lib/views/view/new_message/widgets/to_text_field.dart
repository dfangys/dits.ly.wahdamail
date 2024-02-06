import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class WToTextField extends StatelessWidget {
  WToTextField({
    super.key,
  });

  final TextEditingController textController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('To'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.only(left: 10, right: 10),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey)),
          child: Row(
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width / 1.85,
                child: TextFormField(
                  controller: textController,
                  decoration: InputDecoration(
                      hintText: 'Email ID',
                      hintStyle: TextStyle(color: Colors.grey.shade400)),
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('Cc', style: TextStyle(color: Colors.green)),
              ),
              const Icon(
                CupertinoIcons.person_2_square_stack_fill,
                color: Colors.green,
              )
            ],
          ),
        ),
      ],
    );
  }
}
