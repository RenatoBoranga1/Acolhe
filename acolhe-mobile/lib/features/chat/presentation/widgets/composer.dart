import 'package:acolhe_mobile/shared/widgets/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    required this.controller,
    required this.focusNode,
    required this.canSend,
    required this.isBusy,
    required this.onSend,
    super.key,
    this.errorMessage,
    this.onRetry,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool canSend;
  final bool isBusy;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter &&
            !HardwareKeyboard.instance.isShiftPressed) {
          if (canSend) {
            onSend();
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: ChatComposerBar(
              controller: controller,
              focusNode: focusNode,
              canSend: canSend,
              inputEnabled: true,
              isBusy: isBusy,
              errorMessage: errorMessage,
              onRetry: onRetry,
              onSend: onSend,
            ),
          ),
        ),
      ),
    );
  }
}
