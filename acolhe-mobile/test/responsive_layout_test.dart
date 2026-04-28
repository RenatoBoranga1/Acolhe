import 'package:acolhe_mobile/shared/models/app_models.dart';
import 'package:acolhe_mobile/shared/widgets/responsive_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app viewport breakpoints follow mobile tablet desktop ranges', () {
    expect(AppResponsive.viewportFor(390), AppViewport.mobile);
    expect(AppResponsive.viewportFor(840), AppViewport.tablet);
    expect(AppResponsive.viewportFor(1280), AppViewport.desktop);
  });

  test('inline sidebar is reserved for larger tablet and desktop widths', () {
    expect(AppResponsive.showsInlineSidebar(600), isFalse);
    expect(AppResponsive.showsInlineSidebar(900), isTrue);
    expect(AppResponsive.showsInlineSidebar(1280), isTrue);
  });

  test('auth current app name stays Acolhe even if old alias data exists', () {
    final state = AuthStateModel.initial().copyWith(
      discreetMode: true,
      aliasName: 'Aurora',
    );

    expect(state.currentAppName, 'Acolhe');
  });
}
