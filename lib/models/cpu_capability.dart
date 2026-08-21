enum TargetArch {
  amd64(
    id: 'amd64',
    name: 'AMD64 / x86_64',
    description: '64-bit x86 architecture (Intel/AMD)',
    defaultFlags: ['-m64'],
  ),
  i386(
    id: 'i386',
    name: 'x86 (32-bit)',
    description: '32-bit x86 architecture',
    defaultFlags: ['-m32'],
  ),
  arm64(
    id: 'arm64',
    name: 'ARM64 / AArch64',
    description: '64-bit ARM architecture (Apple Silicon, Graviton, Cortex-A)',
    defaultFlags: [],
  ),
  arm32(
    id: 'arm32',
    name: 'ARMv7 (32-bit)',
    description: '32-bit ARM architecture (Cortex-A/R/M)',
    defaultFlags: [],
  ),
  riscv64(
    id: 'riscv64',
    name: 'RISC-V (64-bit)',
    description: '64-bit open standard RISC-V architecture',
    defaultFlags: [],
  );

  final String id;
  final String name;
  final String description;
  final List<String> defaultFlags;

  const TargetArch({
    required this.id,
    required this.name,
    required this.description,
    required this.defaultFlags,
  });
}

enum OptimizationLevel {
  O0('-O0', 'No Optimization', 'Direct 1:1 translation, keeps all variables in memory stack, best for debugging.'),
  O1('-O1', 'Basic Optimization', 'Basic optimizations, basic register allocation, reduces code size and execution time.'),
  O2('-O2', 'Standard Release', 'Extensive optimizations without space-speed tradeoff. Inlining, instruction scheduling.'),
  O3('-O3', 'Aggressive (SIMD)', 'Maximum speed optimizations, aggressive loop unrolling, auto-vectorization using SIMD.'),
  Ofast('-Ofast', 'Fast Math & Aggressive', '-O3 plus -ffast-math. Disregards strict IEEE 754 float standards for extreme math speed.'),
  Os('-Os', 'Optimize for Size', 'Enables all -O2 optimizations except those that increase code size. Minimizes binary payload.'),
  Og('-Og', 'Debug-Friendly', 'Optimizes for fast compilation and pleasant debugging experience without mangling variables.');

  final String flag;
  final String label;
  final String description;

  const OptimizationLevel(this.flag, this.label, this.description);
}

class CpuFeature {
  final String id;
  final String name;
  final String flag;
  final String category;
  final String description;
  final List<TargetArch> applicableArchs;

  const CpuFeature({
    required this.id,
    required this.name,
    required this.flag,
    required this.category,
    required this.description,
    required this.applicableArchs,
  });
}

class CpuPreset {
  final String id;
  final String name;
  final String description;
  final TargetArch arch;
  final List<String> featureIds;
  final List<String> extraFlags;

  const CpuPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.arch,
    required this.featureIds,
    this.extraFlags = const [],
  });
}

class CpuCapabilitiesData {
  static const List<CpuFeature> allFeatures = [
    // --- x86_64 / AMD64 & i386 Features ---
    CpuFeature(
      id: 'avx512f',
      name: 'AVX-512 Foundation (F)',
      flag: '-mavx512f',
      category: 'AVX-512 SIMD (512-bit)',
      description: '512-bit vector registers (ZMM0-ZMM31), 32 vector registers, 512-bit float/double vector math.',
      applicableArchs: [TargetArch.amd64],
    ),
    CpuFeature(
      id: 'avx512vl',
      name: 'AVX-512 Vector Length (VL)',
      flag: '-mavx512vl',
      category: 'AVX-512 SIMD (512-bit)',
      description: 'Allows AVX-512 operations to operate on 128-bit (XMM) and 256-bit (YMM) registers with EVEX prefix.',
      applicableArchs: [TargetArch.amd64],
    ),
    CpuFeature(
      id: 'avx512bw',
      name: 'AVX-512 Byte and Word (BW)',
      flag: '-mavx512bw',
      category: 'AVX-512 SIMD (512-bit)',
      description: 'Adds 512-bit vector operations for 8-bit (byte) and 16-bit (word) integer types.',
      applicableArchs: [TargetArch.amd64],
    ),
    CpuFeature(
      id: 'avx512dq',
      name: 'AVX-512 Doubleword & Quadword (DQ)',
      flag: '-mavx512dq',
      category: 'AVX-512 SIMD (512-bit)',
      description: 'Adds 512-bit vector operations for 32-bit and 64-bit integer and floating point conversions.',
      applicableArchs: [TargetArch.amd64],
    ),
    CpuFeature(
      id: 'avx512cd',
      name: 'AVX-512 Conflict Detection (CD)',
      flag: '-mavx512cd',
      category: 'AVX-512 SIMD (512-bit)',
      description: 'Vector conflict detection to enable vectorization of loops with potential memory dependencies.',
      applicableArchs: [TargetArch.amd64],
    ),
    CpuFeature(
      id: 'avx2',
      name: 'AVX2 (Advanced Vector Extensions 2)',
      flag: '-mavx2',
      category: 'Vector / SIMD (256-bit)',
      description: '256-bit integer and floating point vector instructions (YMM0-YMM15), gather support, broadcast.',
      applicableArchs: [TargetArch.amd64, TargetArch.i386],
    ),
    CpuFeature(
      id: 'avx',
      name: 'AVX (Advanced Vector Extensions 1)',
      flag: '-mavx',
      category: 'Vector / SIMD (256-bit)',
      description: '256-bit floating point vector instructions, non-destructive 3-operand VEX encoding syntax.',
      applicableArchs: [TargetArch.amd64, TargetArch.i386],
    ),
    CpuFeature(
      id: 'fma',
      name: 'FMA3 (Fused Multiply-Add)',
      flag: '-mfma',
      category: 'Math / Floating Point',
      description: 'Computes (a * b + c) in a single instruction with a single rounding step for higher speed and precision.',
      applicableArchs: [TargetArch.amd64, TargetArch.i386],
    ),
    CpuFeature(
      id: 'sse4_2',
      name: 'SSE 4.2',
      flag: '-msse4.2',
      category: 'Vector / SIMD (128-bit)',
      description: '128-bit vector instructions (XMM), string/text processing instructions, CRC32.',
      applicableArchs: [TargetArch.amd64, TargetArch.i386],
    ),
    CpuFeature(
      id: 'bmi2',
      name: 'BMI / BMI2 (Bit Manipulation)',
      flag: '-mbmi2',
      category: 'Bit Manipulation',
      description: 'Fast bit manipulation instructions: BZHI, MULX, PDEP, PEXT, RORX, SARX, SHLX, SHRX.',
      applicableArchs: [TargetArch.amd64, TargetArch.i386],
    ),
    CpuFeature(
      id: 'popcnt',
      name: 'POPCNT (Population Count)',
      flag: '-mpopcnt',
      category: 'Bit Manipulation',
      description: 'Hardware instruction to count the number of set bits (1s) in a register in 1 cycle.',
      applicableArchs: [TargetArch.amd64, TargetArch.i386],
    ),
    CpuFeature(
      id: 'aes',
      name: 'AES-NI (Hardware AES)',
      flag: '-maes',
      category: 'Cryptography',
      description: 'Hardware accelerated AES encryption and decryption rounds.',
      applicableArchs: [TargetArch.amd64],
    ),
    CpuFeature(
      id: 'march_v2',
      name: 'x86-64-v2 Microarchitecture Level',
      flag: '-march=x86-64-v2',
      category: 'x86-64 Levels',
      description: 'Baseline for ~2009+ CPUs (SSE3, SSSE3, SSE4.1, SSE4.2, POPCNT, CMPXCHG16B).',
      applicableArchs: [TargetArch.amd64],
    ),
    CpuFeature(
      id: 'march_v3',
      name: 'x86-64-v3 Microarchitecture Level',
      flag: '-march=x86-64-v3',
      category: 'x86-64 Levels',
      description: 'Baseline for ~2015+ CPUs (AVX, AVX2, BMI1, BMI2, F16C, FMA, LZCNT, MOVBE, OSXSAVE).',
      applicableArchs: [TargetArch.amd64],
    ),
    CpuFeature(
      id: 'march_v4',
      name: 'x86-64-v4 Microarchitecture Level',
      flag: '-march=x86-64-v4',
      category: 'x86-64 Levels',
      description: 'Baseline for high-end server CPUs with AVX-512 (AVX512F, BW, CD, DQ, VL).',
      applicableArchs: [TargetArch.amd64],
    ),
    CpuFeature(
      id: 'march_native',
      name: 'Target Host CPU (-march=native)',
      flag: '-march=native',
      category: 'Architecture Tuning',
      description: 'Auto-detects and enables all instruction set extensions supported by your current running CPU.',
      applicableArchs: [TargetArch.amd64, TargetArch.i386],
    ),

    // --- ARM / AArch64 Features ---
    CpuFeature(
      id: 'arm_neon',
      name: 'ARM NEON SIMD',
      flag: '-march=armv8-a+simd',
      category: 'Vector / SIMD',
      description: '128-bit SIMD vector engine across 32 registers (V0-V31) for integer and floating point ops.',
      applicableArchs: [TargetArch.arm64, TargetArch.arm32],
    ),
    CpuFeature(
      id: 'arm_sve',
      name: 'ARM SVE (Scalable Vector Extension)',
      flag: '-march=armv8-a+sve',
      category: 'Vector / SIMD',
      description: 'Vector-length agnostic SIMD architecture from 128 to 2048 bits with predicated execution.',
      applicableArchs: [TargetArch.arm64],
    ),
    CpuFeature(
      id: 'arm_sve2',
      name: 'ARM SVE2 (Scalable Vector Extension 2)',
      flag: '-march=armv9-a+sve2',
      category: 'Vector / SIMD',
      description: 'Next-gen SVE2 with DSP, multimedia, and full NEON superset on scalable vector registers.',
      applicableArchs: [TargetArch.arm64],
    ),
    CpuFeature(
      id: 'arm_dotprod',
      name: 'ARM Dot Product (UDOT/SDOT)',
      flag: '-march=armv8.2-a+dotprod',
      category: 'Vector / SIMD',
      description: '8-bit integer dot product instructions for high-throughput machine learning & matrix math.',
      applicableArchs: [TargetArch.arm64],
    ),
    CpuFeature(
      id: 'arm_fp16',
      name: 'ARM Half-Precision (FP16)',
      flag: '-march=armv8.2-a+fp16',
      category: 'Math / Floating Point',
      description: 'Native 16-bit floating point arithmetic instructions for ML and graphics acceleration.',
      applicableArchs: [TargetArch.arm64],
    ),
    CpuFeature(
      id: 'arm_lse',
      name: 'ARM Large System Extensions (LSE Atomics)',
      flag: '-march=armv8.1-a+lse',
      category: 'Atomics & Concurrency',
      description: 'Hardware atomic instructions (LDADD, CAS, SWP) replacing load-linked/store-conditional loops.',
      applicableArchs: [TargetArch.arm64],
    ),
    CpuFeature(
      id: 'arm_crypto',
      name: 'ARM Cryptography Extensions',
      flag: '-march=armv8-a+crypto',
      category: 'Cryptography',
      description: 'Hardware instructions for AES, SHA-1, and SHA-256.',
      applicableArchs: [TargetArch.arm64],
    ),

    // --- RISC-V Features ---
    CpuFeature(
      id: 'rv_v',
      name: 'RISC-V Vector Extension (V)',
      flag: '-march=rv64gcv',
      category: 'Vector / SIMD',
      description: 'Scalable vector extension for RISC-V with vector registers v0-v31 and dynamic vector length.',
      applicableArchs: [TargetArch.riscv64],
    ),
    CpuFeature(
      id: 'rv_b',
      name: 'RISC-V Bitmanip Extension (B)',
      flag: '-march=rv64gc_zba_zbb_zbc_zbs',
      category: 'Bit Manipulation',
      description: 'Address generation, basic bit manipulation, carry-less multiply, and single-bit operations.',
      applicableArchs: [TargetArch.riscv64],
    ),
  ];

  static const List<CpuPreset> presets = [
    CpuPreset(
      id: 'amd64_baseline',
      name: 'Baseline x86-64',
      description: 'Generic 64-bit x86 with SSE2 baseline.',
      arch: TargetArch.amd64,
      featureIds: [],
    ),
    CpuPreset(
      id: 'amd64_modern_desktop',
      name: 'Modern Desktop (AVX2 + FMA + BMI2)',
      description: 'Target standard Intel Core 4th Gen+ and AMD Ryzen (256-bit SIMD, FMA3, BMI2).',
      arch: TargetArch.amd64,
      featureIds: ['avx2', 'fma', 'sse4_2', 'bmi2', 'popcnt'],
    ),
    CpuPreset(
      id: 'amd64_avx512_server',
      name: 'High-End Server (AVX-512 Full)',
      description: 'Intel Xeon Scalable / AMD Zen 4 with full 512-bit ZMM vectorization.',
      arch: TargetArch.amd64,
      featureIds: ['avx512f', 'avx512vl', 'avx512bw', 'avx512dq', 'avx512cd', 'avx2', 'fma', 'bmi2'],
    ),
    CpuPreset(
      id: 'amd64_v3',
      name: 'x86-64-v3 Level',
      description: 'Standard distribution microarchitecture target for modern systems.',
      arch: TargetArch.amd64,
      featureIds: ['march_v3'],
    ),
    CpuPreset(
      id: 'amd64_native',
      name: 'Host Native CPU (-march=native)',
      description: 'Compiles specifically for the exact host processor running this app.',
      arch: TargetArch.amd64,
      featureIds: ['march_native'],
    ),
    CpuPreset(
      id: 'arm64_neon',
      name: 'ARM64 Baseline (NEON SIMD)',
      description: 'Standard 64-bit ARM with 128-bit NEON vector engine.',
      arch: TargetArch.arm64,
      featureIds: ['arm_neon'],
    ),
    CpuPreset(
      id: 'arm64_modern_ml',
      name: 'ARM64 Modern ML (DotProd + FP16 + LSE)',
      description: 'Apple M-Series / ARM Neoverse with fast matrix dot product and atomic instructions.',
      arch: TargetArch.arm64,
      featureIds: ['arm_neon', 'arm_dotprod', 'arm_fp16', 'arm_lse'],
    ),
    CpuPreset(
      id: 'arm64_sve_hpc',
      name: 'ARM SVE Scalable Vector HPC',
      description: 'Supercomputing ARM architecture with scalable vector extension.',
      arch: TargetArch.arm64,
      featureIds: ['arm_sve'],
    ),
    CpuPreset(
      id: 'riscv64_vector',
      name: 'RISC-V 64 Vector (RV64GCV)',
      description: 'RISC-V 64-bit with standard extensions and Vector SIMD support.',
      arch: TargetArch.riscv64,
      featureIds: ['rv_v'],
    ),
  ];
}
