import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_simulator_example/main.dart';

void main() {
  testWidgets('starts the simulation and shows fixes', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const SimulatorDemoApp());
    await tester.pumpAndSettle();
    expect(find.text('Route Simulator'), findsWidgets);

    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Recent fixes'), findsOneWidget);

    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    expect(find.text('Start'), findsOneWidget);
  });
}
