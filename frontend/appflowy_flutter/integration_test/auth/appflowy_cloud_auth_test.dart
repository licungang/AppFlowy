import 'package:appflowy/env/cloud_env.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/workspace/application/settings/prelude.dart';
import 'package:appflowy/workspace/presentation/settings/widgets/settings_user_view.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../util/util.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('appflowy cloud auth', () {
    testWidgets('sign in', (tester) async {
      await tester.initializeAppFlowy(cloudType: CloudType.appflowyCloud);
      await tester.tapGoogleLoginInButton();
      tester.expectToSeeHomePage();
    });

    testWidgets('sign out', (tester) async {
      await tester.initializeAppFlowy(cloudType: CloudType.appflowyCloud);
      await tester.tapGoogleLoginInButton();

      // Open the setting page and sign out
      await tester.openSettings();
      await tester.openSettingsPage(SettingsPage.user);
      await tester.tapButton(find.byType(SettingLogoutButton));

      tester.expectToSeeText(LocaleKeys.button_ok.tr());
      await tester.tapButtonWithName(LocaleKeys.button_ok.tr());

      // Go to the sign in page again
      await tester.pumpAndSettle(const Duration(seconds: 1));
      tester.expectToSeeGoogleLoginButton();
    });

    testWidgets('sign in as annoymous', (tester) async {
      await tester.initializeAppFlowy(cloudType: CloudType.appflowyCloud);
      await tester.tapSignInAsGuest();

      // should not see the sync setting page when sign in as annoymous
      await tester.openSettings();
      await tester.openSettingsPage(SettingsPage.user);
      tester.expectToSeeGoogleLoginButton();
    });

    testWidgets('enable sync', (tester) async {
      await tester.initializeAppFlowy(cloudType: CloudType.appflowyCloud);
      await tester.tapGoogleLoginInButton();

      // Open the setting page and sign out
      await tester.openSettings();
      await tester.openSettingsPage(SettingsPage.cloud);

      // the switch should be on by default
      tester.assertEnableSyncSwitchValue(true);
      await tester.toggleEnableSync();

      // the switch should be off
      tester.assertEnableSyncSwitchValue(false);

      // the switch should be on after toggling
      await tester.toggleEnableSync();
      tester.assertEnableSyncSwitchValue(true);
    });
  });
}
