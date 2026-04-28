import 'package:acolhe_mobile/features/chat/presentation/widgets/composer.dart';
import 'package:acolhe_mobile/shared/widgets/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('chat composer stays visible with keyboard inset and long text',
      (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            viewInsets: EdgeInsets.only(bottom: 320),
          ),
          child: Scaffold(
            resizeToAvoidBottomInset: true,
            body: Column(
              children: [
                const Expanded(child: SizedBox.expand()),
                ChatComposer(
                  controller: controller,
                  focusNode: focusNode,
                  canSend: true,
                  isBusy: false,
                  keyboardInset: 320,
                  maxWidth: 390,
                  onSend: _noop,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      List.filled(18, 'Mensagem longa para testar o campo').join('\n'),
    );
    await tester.pumpAndSettle();

    final composerRect = tester.getRect(find.byType(ChatComposerBar));
    final textField = tester.widget<TextField>(find.byType(TextField));

    expect(composerRect.bottom, lessThanOrEqualTo(560));
    expect(textField.maxLines, 6);
    expect(tester.takeException(), isNull);

    controller.dispose();
    focusNode.dispose();
  });
}

void _noop() {}
