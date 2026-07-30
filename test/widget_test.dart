// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momentum/app.dart';
import 'package:momentum/core/models/app_settings.dart';
import 'package:momentum/routing/app_router.dart';
import 'package:momentum/state/settings_controller.dart';

class _TestSettingsController extends SettingsController {
  @override
  AppSettings build() => AppSettings.initial;
}

void main() {
  testWidgets('app builds with the dashboard shell', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(() => _TestSettingsController()),
          routerProvider.overrideWith(
            (ref) => GoRouter(
              initialLocation: '/',
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => const Scaffold(
                    body: Center(child: Text('Dashboard shell')),
                  ),
                ),
              ],
            ),
          ),
        ],
        child: const MomentumApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Dashboard shell'), findsOneWidget);
  });
}
