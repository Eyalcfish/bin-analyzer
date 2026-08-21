import 'package:flutter_test/flutter_test.dart';
import 'package:bin_analyzer/models/cpu_capability.dart';
import 'package:bin_analyzer/models/snippet.dart';

void main() {
  group('CPU Capabilities & Architecture Models', () {
    test('TargetArch has valid architecture IDs and flags', () {
      expect(TargetArch.amd64.id, equals('amd64'));
      expect(TargetArch.amd64.defaultFlags, contains('-m64'));
      expect(TargetArch.i386.defaultFlags, contains('-m32'));
      expect(TargetArch.arm64.id, equals('arm64'));
      expect(TargetArch.riscv64.id, equals('riscv64'));
    });

    test('Optimization levels contain all required flags', () {
      expect(OptimizationLevel.O0.flag, equals('-O0'));
      expect(OptimizationLevel.O1.flag, equals('-O1'));
      expect(OptimizationLevel.O2.flag, equals('-O2'));
      expect(OptimizationLevel.O3.flag, equals('-O3'));
      expect(OptimizationLevel.Ofast.flag, equals('-Ofast'));
      expect(OptimizationLevel.Os.flag, equals('-Os'));
      expect(OptimizationLevel.Og.flag, equals('-Og'));
    });

    test('AVX-512, AVX2, and ARM NEON features exist in capabilities data', () {
      final features = CpuCapabilitiesData.allFeatures;
      expect(features.any((f) => f.id == 'avx512f'), isTrue);
      expect(features.any((f) => f.id == 'avx2'), isTrue);
      expect(features.any((f) => f.id == 'arm_neon'), isTrue);
      expect(features.any((f) => f.id == 'arm_sve'), isTrue);
    });

    test('Presets contain x86 and ARM configurations', () {
      final presets = CpuCapabilitiesData.presets;
      expect(presets.any((p) => p.id == 'amd64_avx512_server'), isTrue);
      expect(presets.any((p) => p.id == 'amd64_modern_desktop'), isTrue);
      expect(presets.any((p) => p.id == 'arm64_neon'), isTrue);
    });

    test('Default snippet presets are loaded and use hard tabs', () {
      final presets = Snippet.defaultPresets;
      expect(presets.isNotEmpty, isTrue);
      for (final p in presets) {
        expect(p.code.isNotEmpty, isTrue);
        expect(p.code.contains('\t'), isTrue); // obeys C style rule with hard tabs
      }
    });
  });
}
