import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dispatch_mvp/main.dart';
import 'package:dispatch_mvp/providers/auth_provider.dart';
import 'package:dispatch_mvp/providers/order_provider.dart';
import 'package:dispatch_mvp/providers/subscription_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('La app arranca y muestra la pantalla de login', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => OrderProvider()),
          ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ],
        child: const DispatchApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dispatch MVP'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}