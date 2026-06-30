import 'package:flutter_test/flutter_test.dart';
import 'package:hypnosis_downloads/audio_player/session_timings_service.dart';

const _json = '''
{
  "sessions": [
    {
      "filename": "Self-Consciousness.mp3",
      "segments": [
        { "name": "Welcome", "startInSec": 0 },
        { "name": "Hypnotic Induction", "startInSec": 254 },
        { "name": "Reorientation", "startInSec": 1509 }
      ]
    },
    {
      "filename": "Deep-Sleep-Now.mp3",
      "segments": [
        { "name": "Welcome", "startInSec": 0 },
        { "name": "Hypnotic Induction", "startInSec": 210 }
      ]
    },
    {
      "filename": "No-Induction.mp3",
      "segments": [
        { "name": "Reorientation", "startInSec": 100 }
      ]
    }
  ]
}
''';

SessionTimingsService _service() {
  final service = SessionTimingsService()..loadFromString(_json);
  return service;
}

void main() {
  group('SessionTimingsService', () {
    test('returns Hypnotic Induction and Reorientation when present', () async {
      final service = _service();
      expect(
        await service.getHypnoticInductionStart('Self-Consciousness.mp3'),
        const Duration(seconds: 254),
      );
      expect(
        await service.getReorientationStart('Self-Consciousness.mp3'),
        const Duration(seconds: 1509),
      );
    });

    test('returns null Reorientation when the session has none', () async {
      final service = _service();
      expect(
        await service.getHypnoticInductionStart('Deep-Sleep-Now.mp3'),
        const Duration(seconds: 210),
      );
      expect(
        await service.getReorientationStart('Deep-Sleep-Now.mp3'),
        isNull,
      );
    });

    test('returns null Hypnotic Induction when the session has none', () async {
      final service = _service();
      expect(
        await service.getHypnoticInductionStart('No-Induction.mp3'),
        isNull,
      );
      expect(
        await service.getReorientationStart('No-Induction.mp3'),
        const Duration(seconds: 100),
      );
    });

    test('returns null for an unknown filename', () async {
      final service = _service();
      expect(await service.getSegments('Does-Not-Exist.mp3'), isNull);
      expect(
        await service.getHypnoticInductionStart('Does-Not-Exist.mp3'),
        isNull,
      );
    });

    test('matches despite surrounding whitespace and case differences',
        () async {
      final service = _service();
      expect(
        await service.getHypnoticInductionStart('  self-consciousness.MP3  '),
        const Duration(seconds: 254),
      );
    });
  });
}
