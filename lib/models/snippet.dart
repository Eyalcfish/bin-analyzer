import 'cpu_capability.dart';

class Snippet {
  final String id;
  final String title;
  final String description;
  final String category;
  final String code;
  final TargetArch recommendedArch;
  final OptimizationLevel recommendedOpt;
  final List<String> recommendedFeatureIds;
  final bool isPreset;
  final DateTime createdAt;

  Snippet({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.code,
    this.recommendedArch = TargetArch.amd64,
    this.recommendedOpt = OptimizationLevel.O3,
    this.recommendedFeatureIds = const [],
    this.isPreset = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'code': code,
      'recommended_arch': recommendedArch.id,
      'recommended_opt': recommendedOpt.flag,
      'recommended_features': recommendedFeatureIds.join(','),
      'is_preset': isPreset ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Snippet.fromMap(Map<String, dynamic> map) {
    TargetArch arch = TargetArch.amd64;
    try {
      arch = TargetArch.values.firstWhere((a) => a.id == map['recommended_arch']);
    } catch (_) {}

    OptimizationLevel opt = OptimizationLevel.O3;
    try {
      opt = OptimizationLevel.values.firstWhere((o) => o.flag == map['recommended_opt']);
    } catch (_) {}

    final featuresStr = map['recommended_features'] as String? ?? '';
    final featureIds = featuresStr.isEmpty ? <String>[] : featuresStr.split(',');

    return Snippet(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      category: map['category'] as String,
      code: map['code'] as String,
      recommendedArch: arch,
      recommendedOpt: opt,
      recommendedFeatureIds: featureIds,
      isPreset: (map['is_preset'] as int? ?? 0) == 1,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  static List<Snippet> get defaultPresets => [
    Snippet(
      id: 'preset_vector_add',
      title: 'AVX-512 / AVX2 Vector Float Addition',
      description: 'Observe auto-vectorization across -O0 (scalar stack), -O3 (AVX2 YMM 256-bit), and -O3 + AVX-512 (ZMM 512-bit registers).',
      category: 'SIMD & Vectorization',
      recommendedArch: TargetArch.amd64,
      recommendedOpt: OptimizationLevel.O3,
      recommendedFeatureIds: ['avx512f', 'avx2'],
      isPreset: true,
      code: '''void vector_add(float* restrict a, float* restrict b, float* restrict c, int count) {
\tfor (int i = 0; i < count; i++) {
\t\tc[i] = a[i] + b[i];
\t}
}
''',
    ),
    Snippet(
      id: 'preset_dot_product',
      title: 'Fused Multiply-Add (FMA) & Dot Product',
      description: 'Multiplies and accumulates arrays using single-cycle FMA / VFMADD231PS instructions without intermediate rounding loss.',
      category: 'SIMD & Vectorization',
      recommendedArch: TargetArch.amd64,
      recommendedOpt: OptimizationLevel.O3,
      recommendedFeatureIds: ['avx2', 'fma'],
      isPreset: true,
      code: '''float dot_product(const float* restrict a, const float* restrict b, int length) {
\tfloat sum = 0.0f;
\tfor (int i = 0; i < length; i++) {
\t\tsum += a[i] * b[i];
\t}
\treturn sum;
}
''',
    ),
    Snippet(
      id: 'preset_branchless_cmov',
      title: 'Branchless Clamping (CMOV / CSEL)',
      description: 'Demonstrates how the compiler avoids branch prediction penalties by generating CMOV (x86) or CSEL (ARM) conditional moves.',
      category: 'Branching & Control Flow',
      recommendedArch: TargetArch.amd64,
      recommendedOpt: OptimizationLevel.O2,
      recommendedFeatureIds: [],
      isPreset: true,
      code: '''int clamp_range(int value, int min_val, int max_val) {
\tif (value < min_val) {
\t\treturn min_val;
\t} else if (value > max_val) {
\t\treturn max_val;
\t}
\treturn value;
}
''',
    ),
    Snippet(
      id: 'preset_popcount_bmi',
      title: 'Bit Counting & Hardware POPCNT / BMI2',
      description: 'Direct comparison between custom loop bit counting and hardware POPCNT / BMI2 instruction generation.',
      category: 'Bit Manipulation',
      recommendedArch: TargetArch.amd64,
      recommendedOpt: OptimizationLevel.O3,
      recommendedFeatureIds: ['popcnt', 'bmi2'],
      isPreset: true,
      code: '''unsigned int count_set_bits(unsigned int n) {
\treturn (unsigned int)__builtin_popcount(n);
}

unsigned int rotate_and_extract(unsigned int x) {
\t// Compiler turns this into RORX on BMI2
\treturn (x >> 5) | (x << (32 - 5));
}
''',
    ),
    Snippet(
      id: 'preset_tail_recursion',
      title: 'Tail Call Optimization (TCO)',
      description: 'Shows how recursive tail calls are transformed into a zero-overhead iterative loop without stack frames at -O2/-O3.',
      category: 'Functions & Inlining',
      recommendedArch: TargetArch.amd64,
      recommendedOpt: OptimizationLevel.O2,
      recommendedFeatureIds: [],
      isPreset: true,
      code: '''long long factorial_helper(long long n, long long accumulator) {
\tif (n <= 1) {
\t\treturn accumulator;
\t}
\treturn factorial_helper(n - 1, n * accumulator);
}

long long factorial(long long n) {
\treturn factorial_helper(n, 1);
}
''',
    ),
    Snippet(
      id: 'preset_switch_table',
      title: 'Switch Statement: Jump Table vs Tree',
      description: 'Observe how GCC decides between a contiguous jump table dispatch (jmp [table + rax*8]) vs a binary decision tree.',
      category: 'Branching & Control Flow',
      recommendedArch: TargetArch.amd64,
      recommendedOpt: OptimizationLevel.O2,
      recommendedFeatureIds: [],
      isPreset: true,
      code: '''int compute_operation(int op, int a, int b) {
\tswitch (op) {
\t\tcase 0: return a + b;
\t\tcase 1: return a - b;
\t\tcase 2: return a * b;
\t\tcase 3: return b != 0 ? a / b : 0;
\t\tcase 4: return a ^ b;
\t\tcase 5: return a | b;
\t\tcase 6: return a & b;
\t\tdefault: return 0;
\t}
}
''',
    ),
    Snippet(
      id: 'preset_fast_math',
      title: 'Fast-Math Optimization (-Ofast)',
      description: 'Inspect algebraic simplification and reassociation permitted under -Ofast that standard IEEE 754 prohibits.',
      category: 'Math & Floating Point',
      recommendedArch: TargetArch.amd64,
      recommendedOpt: OptimizationLevel.Ofast,
      recommendedFeatureIds: ['avx2', 'fma'],
      isPreset: true,
      code: '''float evaluate_poly(float x) {
\t// (x + 1) * (x + 1) - (x * x) -> Simplifies to 2*x + 1 under -Ofast
\tfloat a = (x + 1.0f) * (x + 1.0f);
\tfloat b = x * x;
\treturn a - b;
}
''',
    ),
    Snippet(
      id: 'preset_struct_alignment',
      title: 'Struct Memory Alignment & Padding',
      description: 'Observe how field order affects struct size and generated assembly offsets for memory loads and stores.',
      category: 'Memory & Cache',
      recommendedArch: TargetArch.amd64,
      recommendedOpt: OptimizationLevel.O2,
      recommendedFeatureIds: [],
      isPreset: true,
      code: '''struct UnalignedStruct {
\tchar a;
\tint b;
\tchar c;
\tlong long d;
};

struct AlignedStruct {
\tlong long d;
\tint b;
\tchar a;
\tchar c;
};

long long access_fields(struct UnalignedStruct* s) {
\treturn s->a + s->b + s->c + s->d;
}
''',
    ),
    Snippet(
      id: 'preset_volatile_deadcode',
      title: 'Volatile vs Dead Code Elimination',
      description: 'See how GCC removes unused calculations entirely in normal code, but is forced to emit loads/stores for volatile variables.',
      category: 'Memory & Cache',
      recommendedArch: TargetArch.amd64,
      recommendedOpt: OptimizationLevel.O2,
      recommendedFeatureIds: [],
      isPreset: true,
      code: '''int normal_loop(int count) {
\tint x = 0;
\tfor (int i = 0; i < count; i++) {
\t\tx += i; // Optimized away to constant formula: count*(count-1)/2
\t}
\treturn x;
}

void volatile_hardware_poll(volatile int* hardware_register) {
\twhile (*hardware_register == 0) {
\t\t// GCC cannot optimize this loop away because memory access is volatile
\t}
}
''',
    ),
  ];
}
