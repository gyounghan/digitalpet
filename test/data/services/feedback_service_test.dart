import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfriend/data/services/feedback_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <String>[];

  setUp(() {
    calls.clear();
    FeedbackService.enabled = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call.arguments?.toString() ?? 'vibrate');
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    FeedbackService.enabled = true;
  });

  test('enabled=true면 햅틱 플랫폼 호출이 발생한다', () async {
    FeedbackService.medium();
    FeedbackService.success();
    await Future<void>.delayed(Duration.zero);
    expect(calls, isNotEmpty);
  });

  test('enabled=false면 햅틱을 호출하지 않는다', () async {
    FeedbackService.enabled = false;
    FeedbackService.light();
    FeedbackService.medium();
    FeedbackService.success();
    FeedbackService.error();
    await Future<void>.delayed(Duration.zero);
    expect(calls, isEmpty);
  });
}
