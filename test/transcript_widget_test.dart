// Tests for the conversation transcript view and the typed text input bar.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:embla/assistant/conversation.dart';
import 'package:embla/transcript_widget.dart';

// Wrap a widget in the minimum scaffolding needed to pump it
Widget wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: SizedBox(height: 300, child: child)));
}

void main() {
  group('TranscriptView', () {
    testWidgets('shows the intro message when the conversation is empty', (tester) async {
      final Conversation conv = Conversation();
      await tester.pumpWidget(wrap(TranscriptView(
        conversation: conv,
        emptyMessage: 'Smelltu á hnappinn',
      )));
      expect(find.text('Smelltu á hnappinn'), findsOneWidget);
    });

    testWidgets('renders user, assistant and tool turns', (tester) async {
      final Conversation conv = Conversation();
      await tester.pumpWidget(wrap(TranscriptView(conversation: conv, emptyMessage: 'halló')));

      conv.addUser('hvað er klukkan');
      conv.addToolActivity('Leita í Greynir…');
      conv.addAssistant('Klukkan er tvö.');
      await tester.pumpAndSettle();

      expect(find.text('halló'), findsNothing);
      expect(find.text('hvað er klukkan'), findsOneWidget);
      expect(find.text('Leita í Greynir…'), findsOneWidget);
      expect(find.text('Klukkan er tvö.'), findsOneWidget);

      // The user turn is right-aligned and bold, the tool turn small and italic
      final SelectableText userText = tester.widget(find.ancestor(
          of: find.text('hvað er klukkan'), matching: find.byType(SelectableText)));
      expect(userText.textAlign, TextAlign.right);
      expect(userText.style?.fontWeight, FontWeight.bold);
      final Text toolText = tester.widget(find.text('Leita í Greynir…'));
      expect(toolText.style?.fontStyle, FontStyle.italic);
    });

    testWidgets('shows the image of the last assistant turn', (tester) async {
      final Conversation conv = Conversation();
      conv.addUser('mynd af kött');
      conv.addAssistant('Hér er hún.', imageURL: 'https://example.com/cat.png');
      await tester.pumpWidget(wrap(TranscriptView(conversation: conv)));
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('long press starts a new conversation', (tester) async {
      final Conversation conv = Conversation();
      conv.addUser('halló');
      int resets = 0;
      await tester.pumpWidget(wrap(TranscriptView(
        conversation: conv,
        onNewConversation: () {
          conv.reset();
          resets += 1;
        },
      )));
      await tester.longPress(find.byType(TranscriptView));
      await tester.pumpAndSettle();
      expect(resets, 1);
      expect(conv.turns, isEmpty);
    });
  });

  group('TextInputBar', () {
    testWidgets('submitting via the send button calls back and clears the field',
        (tester) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      String? submitted;
      await tester.pumpWidget(wrap(TextInputBar(
        controller: controller,
        onSubmit: (String t) => submitted = t,
      )));

      await tester.enterText(find.byType(TextField), 'hvað er klukkan');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(submitted, 'hvað er klukkan');
      expect(controller.text, '');
    });

    testWidgets('submitting from the keyboard calls back', (tester) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      String? submitted;
      await tester.pumpWidget(wrap(TextInputBar(
        controller: controller,
        onSubmit: (String t) => submitted = t,
      )));

      await tester.enterText(find.byType(TextField), '  hver skrifaði Njálu  ');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();

      expect(submitted, 'hver skrifaði Njálu');
      expect(controller.text, '');
    });

    testWidgets('whitespace-only input is ignored', (tester) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      int calls = 0;
      await tester.pumpWidget(wrap(TextInputBar(
        controller: controller,
        onSubmit: (String t) => calls += 1,
      )));

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
      expect(calls, 0);
    });

    testWidgets('is disabled while a session is active', (tester) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(wrap(TextInputBar(
        controller: controller,
        enabled: false,
        onSubmit: (String t) {},
      )));

      final TextField field = tester.widget(find.byType(TextField));
      expect(field.enabled, false);
      final IconButton sendButton = tester.widget(
          find.ancestor(of: find.byIcon(Icons.send), matching: find.byType(IconButton)));
      expect(sendButton.onPressed, isNull);
    });

    testWidgets('the new conversation button is only shown when wired up', (tester) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(wrap(TextInputBar(controller: controller, onSubmit: (String t) {})));
      expect(find.byType(IconButton), findsOneWidget);

      int resets = 0;
      await tester.pumpWidget(wrap(TextInputBar(
        controller: controller,
        onSubmit: (String t) {},
        onNewConversation: () => resets += 1,
      )));
      expect(find.byType(IconButton), findsNWidgets(2));
      await tester.tap(find.byIcon(Icons.add_comment_outlined));
      await tester.pumpAndSettle();
      expect(resets, 1);
    });
  });
}
