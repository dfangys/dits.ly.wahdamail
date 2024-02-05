import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:wahda_bank/widgets/listile/archieve_cuperchinoDilougebox.dart';

class ListTileCupertinoDilaogue extends StatelessWidget {
  const ListTileCupertinoDilaogue({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: SizedBox(
        height: MediaQuery.of(context).size.height / 1.5,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ArchieveCupercionoDilaogeBox(
                  icon: CupertinoIcons.check_mark_circled_solid,
                  onTap: () {},
                  text: 'Mark as read/unread',
                  backgroundColor: Colors.blue,
                  iconColor: Colors.blue,
                  opacity: 0.2,
                ),
                ArchieveCupercionoDilaogeBox(
                  icon: CupertinoIcons.archivebox,
                  onTap: () {},
                  text: 'Archieve',
                  backgroundColor: Colors.yellow,
                  iconColor: Colors.red,
                  opacity: 0.3,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ArchieveCupercionoDilaogeBox(
                  icon: CupertinoIcons.ant_circle,
                  onTap: () {},
                  text: 'Mark as junk',
                  backgroundColor: Colors.red,
                  iconColor: Colors.red,
                  opacity: 0.4,
                ),
                ArchieveCupercionoDilaogeBox(
                  icon: CupertinoIcons.delete,
                  textColor: Colors.white,
                  onTap: () {},
                  text: 'Delete',
                  backgroundColor: Colors.red,
                  iconColor: Colors.white,
                  opacity: 0.9,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ArchieveCupercionoDilaogeBox(
                  icon: CupertinoIcons.flag,
                  onTap: () {},
                  text: 'Toggle Flag',
                  backgroundColor: Colors.green,
                  iconColor: Colors.grey,
                  opacity: 0.8,
                ),
                const SizedBox(
                  height: 50,
                  width: 80,
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}
