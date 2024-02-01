import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ComposeActionButton extends StatelessWidget {
  const ComposeActionButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(15),
              topRight: Radius.circular(15),
            ),
          ),
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Colors.green,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                ),
                child: InkWell(
                  onTap: () {},
                  child: const Padding(
                    padding: EdgeInsets.all(10.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'From Files',
                          style: TextStyle(color: Colors.white),
                        ),
                        Icon(
                          Icons.file_copy,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Material(
                color: Colors.green,
                child: InkWell(
                  onTap: () {
                    Get.back();
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(10.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'From Photos',
                          style: TextStyle(color: Colors.white),
                        ),
                        Icon(
                          Icons.photo,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Material(
                color: Colors.green,
                child: InkWell(
                  onTap: () {
                    Get.back();
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(10.0),
                    child: Center(
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      icon: Image.asset("assets/png/attatch.png"),
    );
  }
}
