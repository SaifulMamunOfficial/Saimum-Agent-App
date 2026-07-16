import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:academy_collector/controllers/app_state.dart';
import 'package:academy_collector/main.dart';

void main() {
  testWidgets('App initialization and login screen smoke test', (WidgetTester tester) async {
    final appState = AppState();
    
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    // Verify that the login title or widgets are loaded.
    expect(find.text('সাইমুম একাডেমী'), findsOneWidget);
    expect(find.text('ফি কালেকশন ম্যানেজমেন্ট সিস্টেম'), findsOneWidget);
  });
}
