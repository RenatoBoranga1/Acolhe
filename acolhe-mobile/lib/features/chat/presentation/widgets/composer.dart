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
    required this.maxWidth,
    super.key,
    this.errorMessage,
    this.compactMode = false,
    this.keyboardInset = 0,
    this.onRetry,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool canSend;
  final bool isBusy;
  final double maxWidth;
  final double keyboardInset;
  final bool compactMode;
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
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(bottom: keyboardInset > 0 ? 8 : 0),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: ChatComposerBar(
                controller: controller,
                focusNode: focusNode,
                canSend: canSend,
                inputEnabled: true,
                isBusy: isBusy,
                compactMode: compactMode,
                errorMessage: errorMessage,
                onRetry: onRetry,
                onSend: onSend,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
