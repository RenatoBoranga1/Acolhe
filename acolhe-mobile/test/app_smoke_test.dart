import 'package:acolhe_mobile/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app bootstraps', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AcolheApp()));
    await tester.pump();
    expect(find.textContaining('Acolhe'), findsAny);
  });
}
