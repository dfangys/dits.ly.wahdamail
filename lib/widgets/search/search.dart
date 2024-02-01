import 'package:flutter/material.dart';

class SearchView extends StatelessWidget {
  SearchView({super.key});
  final textController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        // leading: IconButton(
        //     onPressed: () {
        //       Get.back();
        //     },
        //     icon: const Icon(Icons.arrow_back_ios)),
        title: TextFormField(
          controller: textController,
          onChanged: (String txt) {
            // onSearch(txt);
          },
          decoration: InputDecoration(
            fillColor: const Color(0xFF37373F1A),
            filled: true,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            hintText: "Search",
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide.none,
            ),
            suffixIconConstraints: const BoxConstraints(
              maxHeight: 18,
              minWidth: 40,
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 2,
                  height: 20,
                  color: Colors.grey.shade400,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                ),
                GestureDetector(
                  onTap: () {},
                  child: const Icon(
                    Icons.search,
                    color: Colors.black,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
