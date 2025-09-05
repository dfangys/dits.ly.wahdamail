import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Compose toolbar focus traversal uses ReadingOrderTraversalPolicy',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(),
              child: Row(
                children: const [
                  IconButton(onPressed: null, icon: Icon(Icons.code)),
                  IconButton(onPressed: null, icon: Icon(Icons.attach_file)),
                  IconButton(onPressed: null, icon: Icon(Icons.flag)),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(FocusTraversalGroup), findsWidgets);
    },
  );
}
