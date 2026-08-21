import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/cpu_capability.dart';
import '../models/executable_binary.dart';
import '../services/compiler_service.dart';
import '../services/executable_service.dart';

class ExecutableProvider extends ChangeNotifier {
  final ExecutableService _executableService = ExecutableService.instance;
  final CompilerService _compilerService = CompilerService();

  ExecutableBinary? _binary;
  bool _isLoading = false;
  String? _errorMessage;

  // Filters & Navigation
  String _selectedSection = 'All';
  String? _selectedFunction;
  String _searchQuery = '';
  int? _highlightAddress;
  final List<int> _navigationHistory = [];

  // Multi-format Quick In-App Compiler State
  BinaryOutputFormat _selectedOutputFormat = BinaryOutputFormat.peExe;
  bool _isCompilingFromC = false;

  // Getters
  ExecutableBinary? get binary => _binary;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get selectedSection => _selectedSection;
  String? get selectedFunction => _selectedFunction;
  String get searchQuery => _searchQuery;
  int? get highlightAddress => _highlightAddress;
  BinaryOutputFormat get selectedOutputFormat => _selectedOutputFormat;
  bool get isCompilingFromC => _isCompilingFromC;
  List<int> get navigationHistory => _navigationHistory;
  bool get canGoBack => _navigationHistory.isNotEmpty;

  List<String> get availableSectionNames {
    if (_binary == null) return ['All'];
    return ['All', ..._binary!.sections.map((s) => s.name)];
  }

  List<ExecutableSection> get filteredSections {
    if (_binary == null) return [];
    if (_selectedSection == 'All') return _binary!.sections;
    return _binary!.sections.where((s) => s.name == _selectedSection).toList();
  }

  List<ExecutableSymbol> get filteredSymbols {
    if (_binary == null) return [];
    final q = _searchQuery.trim().toLowerCase();
    return _binary!.symbols.where((s) {
      final matchesQuery = q.isEmpty ||
          s.name.toLowerCase().contains(q) ||
          s.virtualAddress.toRadixString(16).toLowerCase().contains(q);
      final matchesSection = _selectedSection == 'All' || s.sectionName == _selectedSection;
      return matchesQuery && matchesSection;
    }).toList();
  }

  List<ExecutableInstruction> get filteredInstructions {
    if (_binary == null) return [];
    final q = _searchQuery.trim().toLowerCase();

    // Check if function filtering is active
    if (_selectedFunction != null && _selectedFunction!.isNotEmpty && _selectedFunction != 'All') {
      final targetFn = _selectedFunction!;
      final exactMatches = _binary!.instructions.where((insn) => insn.functionName == targetFn).toList();

      if (exactMatches.isNotEmpty) {
        return exactMatches.where((insn) {
          if (q.isEmpty) return true;
          return insn.mnemonic.toLowerCase().contains(q) ||
              insn.operands.toLowerCase().contains(q) ||
              insn.virtualAddress.toRadixString(16).toLowerCase().contains(q);
        }).toList();
      }

      // Address range matching fallback for symbols without exact function name
      final symIndex = _binary!.symbols.indexWhere((s) => s.name == targetFn);
      if (symIndex != -1) {
        final startAddr = _binary!.symbols[symIndex].virtualAddress;
        int? endAddr;
        for (int i = symIndex + 1; i < _binary!.symbols.length; i++) {
          if (_binary!.symbols[i].virtualAddress > startAddr) {
            endAddr = _binary!.symbols[i].virtualAddress;
            break;
          }
        }

        final rangeMatches = _binary!.instructions.where((insn) {
          return insn.virtualAddress >= startAddr && (endAddr == null || insn.virtualAddress < endAddr);
        }).toList();

        if (rangeMatches.isNotEmpty) {
          return rangeMatches.where((insn) {
            if (q.isEmpty) return true;
            return insn.mnemonic.toLowerCase().contains(q) ||
                insn.operands.toLowerCase().contains(q) ||
                insn.virtualAddress.toRadixString(16).toLowerCase().contains(q);
          }).toList();
        }
      }
    }

    // Default: Filter by section and search query
    return _binary!.instructions.where((insn) {
      if (_selectedSection != 'All') {
        final sec = _binary!.sections.where((s) => s.name == _selectedSection).firstOrNull;
        if (sec != null && sec.virtualSize > 0) {
          if (insn.virtualAddress < sec.virtualAddress || insn.virtualAddress >= sec.virtualAddress + sec.virtualSize) {
            return false;
          }
        }
      }
      if (q.isEmpty) return true;
      return insn.mnemonic.toLowerCase().contains(q) ||
          insn.operands.toLowerCase().contains(q) ||
          insn.virtualAddress.toRadixString(16).toLowerCase().contains(q) ||
          (insn.functionName?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  ExecutableProvider() {
    _loadInitialDemo();
  }

  Future<void> _loadInitialDemo() async {
    await loadDemoBinary(BinaryOutputFormat.peExe);
  }

  Future<void> loadExecutableFile(String filePath) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final bin = await _executableService.analyzeExecutableFile(filePath);
      _binary = bin;
      _selectedSection = 'All';
      _selectedFunction = null;
      _searchQuery = '';
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error loading executable: $e';
      notifyListeners();
    }
  }

  Future<void> loadExecutableBytes(Uint8List bytes, {String fileName = 'binary.bin', String? filePath}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final bin = await _executableService.analyzeExecutableBytes(bytes, fileName: fileName, filePath: filePath);
      _binary = bin;
      _selectedSection = 'All';
      _selectedFunction = null;
      _searchQuery = '';
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error analyzing binary bytes: $e';
      notifyListeners();
    }
  }

  Future<void> loadDemoBinary(BinaryOutputFormat format) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    const sampleC = '''
int compute_sum(int a, int b) {
    return a + b * 2;
}

int vector_calc(int* arr, int n) {
    int sum = 0;
    for (int i = 0; i < n; i++) {
        sum += arr[i] * arr[i];
    }
    return sum;
}

int main() {
    int nums[4] = {1, 2, 3, 4};
    int res = compute_sum(10, 20);
    int vec = vector_calc(nums, 4);
    return res + vec;
}
''';

    try {
      final compResult = await _compilerService.compileToBinaryFile(
        sourceCode: sampleC,
        format: format,
        arch: TargetArch.amd64,
        optLevel: OptimizationLevel.O2,
      );

      if (compResult.success) {
        await loadExecutableFile(compResult.outputPath);
      } else {
        _isLoading = false;
        _errorMessage = 'Failed to generate demo binary: ${compResult.stderr}';
        notifyListeners();
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error building demo binary: $e';
      notifyListeners();
    }
  }

  Future<bool> compileFromSourceCode({
    required String sourceCode,
    required BinaryOutputFormat format,
    required TargetArch arch,
    required OptimizationLevel optLevel,
    List<String> cpuFlags = const [],
    String extraFlags = '',
  }) async {
    _isCompilingFromC = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _compilerService.compileToBinaryFile(
        sourceCode: sourceCode,
        format: format,
        arch: arch,
        optLevel: optLevel,
        cpuFlags: cpuFlags,
        extraFlags: extraFlags,
      );

      _isCompilingFromC = false;

      if (result.success) {
        await loadExecutableFile(result.outputPath);
        return true;
      } else {
        _errorMessage = 'Compilation failed:\n${result.stderr}';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isCompilingFromC = false;
      _errorMessage = 'Compilation error: $e';
      notifyListeners();
      return false;
    }
  }

  void setSelectedSection(String sectionName) {
    _selectedSection = sectionName;
    notifyListeners();
  }

  void setSelectedFunction(String? functionName) {
    _selectedFunction = functionName;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setHighlightAddress(int? address) {
    _highlightAddress = address;
    notifyListeners();
  }

  /// Navigate to a target address (from a call/jmp click).
  /// Pushes the source instruction address onto the navigation stack so the user can go back.
  void navigateToAddress(int targetAddress, {int? sourceAddress}) {
    if (sourceAddress != null) {
      _navigationHistory.add(sourceAddress);
    } else if (_highlightAddress != null) {
      _navigationHistory.add(_highlightAddress!);
    }
    // Clear filters and search so the target instruction is in the visible instructions list
    _selectedSection = 'All';
    _selectedFunction = null;
    _searchQuery = '';
    _highlightAddress = targetAddress;
    notifyListeners();
  }

  /// Go back to the previous navigation address.
  void navigateBack() {
    if (_navigationHistory.isEmpty) return;
    final prevAddr = _navigationHistory.removeLast();
    _selectedFunction = null;
    _highlightAddress = prevAddr;
    notifyListeners();
  }

  void setOutputFormat(BinaryOutputFormat format) {
    _selectedOutputFormat = format;
    notifyListeners();
  }

  // --- Patching Actions ---
  void applyBytePatch({
    required int fileOffset,
    required int virtualAddress,
    required Uint8List newBytes,
    String patchedAsm = '',
    String description = '',
  }) {
    if (_binary == null) return;

    final origBytes = _binary!.byteBuffer.sublist(
      fileOffset,
      fileOffset + newBytes.length <= _binary!.byteBuffer.length
          ? fileOffset + newBytes.length
          : _binary!.byteBuffer.length,
    );

    final patch = BinaryPatch(
      id: const Uuid().v4().substring(0, 8),
      fileOffset: fileOffset,
      virtualAddress: virtualAddress,
      originalBytes: origBytes,
      patchedBytes: newBytes,
      originalAsm: '',
      patchedAsm: patchedAsm,
      description: description,
    );

    _binary = _executableService.applyPatch(_binary!, patch);
    notifyListeners();
  }

  Future<void> exportPatchedBinary(String outputPath) async {
    if (_binary == null) return;
    await _executableService.exportBinary(_binary!, outputPath);
  }
}
