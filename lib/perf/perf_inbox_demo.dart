import 'package:flutter/material.dart';

/// PerfInboxDemo simulates an inbox with > 1,500 items to enable repeatable
/// profile runs without network or DB variability.
class PerfInboxDemo extends StatelessWidget {
  const PerfInboxDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final items = List.generate(2000, (i) => i);
    return Scaffold(
      appBar: AppBar(title: const Text('Perf Inbox Demo')),
      body: CustomScrollView(
        key: const Key('perf_inbox_scroll'),
        slivers: [
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return const _PerfTile();
              },
              childCount: items.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _PerfTile extends StatelessWidget {
  const _PerfTile();
  @override
  Widget build(BuildContext context) {
    // Lightweight, mostly-const layout approximating a mail tile
    return const ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(radius: 18, backgroundColor: Color(0xFFE3F2FD)),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sender Name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Subject line preview goes here',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Short preview text of the message, normalized and truncated to avoid layout shifts.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.attach_file, size: 16, color: Colors.blue),
          ],
        ),
      ),
    );
  }
}

