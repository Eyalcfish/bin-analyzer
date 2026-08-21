import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/compilation_result.dart';
import '../models/cpu_capability.dart';
import '../models/snippet.dart';
import '../services/compiler_service.dart';
import '../services/database_service.dart';

class ExplorerProvider extends ChangeNotifier {
  final CompilerService compilerService = CompilerService();
  final DatabaseService databaseService = DatabaseService.instance;

  // Editor & Settings State
  String _code = Snippet.defaultPresets.first.code;
  Snippet? _currentSnippet = Snippet.defaultPresets.first;
  TargetArch _arch = TargetArch.amd64;
  OptimizationLevel _optLevel = OptimizationLevel.O3;
  final Set<String> _selectedFeatureIds = {'avx512f', 'avx2'};
  String _syntax = 'intel';
  bool _cleanDirectives = true;
  String _extraFlags = '';

  // Primary Compilation State
  bool _isCompiling = false;
  CompilationResult? _result;

  // Comparison State
  bool _isComparisonMode = false;
  TargetArch _compareArch = TargetArch.amd64;
  OptimizationLevel _compareOptLevel = OptimizationLevel.O0;
  final Set<String> _compareFeatureIds = {};
  bool _isCompareCompiling = false;
  CompilationResult? _compareResult;

  // Database & Library State
  List<Snippet> _snippets = [];
  List<String> _categories = [];
  String _searchQuery = '';
  String _selectedCategory = 'All';

  // Getters
  String get code => _code;
  Snippet? get currentSnippet => _currentSnippet;
  TargetArch get arch => _arch;
  OptimizationLevel get optLevel => _optLevel;
  Set<String> get selectedFeatureIds => _selectedFeatureIds;
  String get syntax => _syntax;
  bool get cleanDirectives => _cleanDirectives;
  String get extraFlags => _extraFlags;
  bool get isCompiling => _isCompiling;
  CompilationResult? get result => _result;

  bool get isComparisonMode => _isComparisonMode;
  TargetArch get compareArch => _compareArch;
  OptimizationLevel get compareOptLevel => _compareOptLevel;
  Set<String> get compareFeatureIds => _compareFeatureIds;
  bool get isCompareCompiling => _isCompareCompiling;
  CompilationResult? get compareResult => _compareResult;

  List<Snippet> get snippets => _snippets;
  List<String> get categories => _categories;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;

  List<String> get activeCpuFlags {
    final flags = <String>[];
    for (final id in _selectedFeatureIds) {
      final feat = CpuCapabilitiesData.allFeatures.where((f) => f.id == id).firstOrNull;
      if (feat != null && feat.applicableArchs.contains(_arch)) {
        flags.add(feat.flag);
      }
    }
    return flags;
  }

  List<String> get compareActiveCpuFlags {
    final flags = <String>[];
    for (final id in _compareFeatureIds) {
      final feat = CpuCapabilitiesData.allFeatures.where((f) => f.id == id).firstOrNull;
      if (feat != null && feat.applicableArchs.contains(_compareArch)) {
        flags.add(feat.flag);
      }
    }
    return flags;
  }

  ExplorerProvider() {
    _init();
  }

  Future<void> _init() async {
    await refreshSnippets();
    await compile();
  }

  void setCode(String newCode) {
    _code = newCode;
    notifyListeners();
  }

  void setArch(TargetArch newArch) {
    _arch = newArch;
    // Auto adjust incompatible features
    _selectedFeatureIds.removeWhere((id) {
      final feat = CpuCapabilitiesData.allFeatures.where((f) => f.id == id).firstOrNull;
      return feat != null && !feat.applicableArchs.contains(newArch);
    });
    notifyListeners();
    compile();
  }

  void setOptLevel(OptimizationLevel newOpt) {
    _optLevel = newOpt;
    notifyListeners();
    compile();
  }

  void toggleCpuFeature(String featureId) {
    if (_selectedFeatureIds.contains(featureId)) {
      _selectedFeatureIds.remove(featureId);
    } else {
      _selectedFeatureIds.add(featureId);
    }
    notifyListeners();
    compile();
  }

  void setCpuFeatures(Iterable<String> featureIds) {
    _selectedFeatureIds.clear();
    _selectedFeatureIds.addAll(featureIds);
    notifyListeners();
    compile();
  }

  void applyCpuPreset(CpuPreset preset) {
    _arch = preset.arch;
    _selectedFeatureIds.clear();
    _selectedFeatureIds.addAll(preset.featureIds);
    notifyListeners();
    compile();
  }

  void clearCpuFeatures() {
    _selectedFeatureIds.clear();
    notifyListeners();
    compile();
  }

  void setSyntax(String newSyntax) {
    _syntax = newSyntax;
    notifyListeners();
    compile();
  }

  void setCleanDirectives(bool val) {
    _cleanDirectives = val;
    notifyListeners();
  }

  void setExtraFlags(String val) {
    _extraFlags = val;
    notifyListeners();
  }

  void toggleComparisonMode() {
    _isComparisonMode = !_isComparisonMode;
    if (_isComparisonMode && _compareResult == null) {
      compileComparison();
    }
    notifyListeners();
  }

  void setCompareArch(TargetArch newArch) {
    _compareArch = newArch;
    _compareFeatureIds.removeWhere((id) {
      final feat = CpuCapabilitiesData.allFeatures.where((f) => f.id == id).firstOrNull;
      return feat != null && !feat.applicableArchs.contains(newArch);
    });
    notifyListeners();
    compileComparison();
  }

  void setCompareOptLevel(OptimizationLevel newOpt) {
    _compareOptLevel = newOpt;
    notifyListeners();
    compileComparison();
  }

  void toggleCompareCpuFeature(String featureId) {
    if (_compareFeatureIds.contains(featureId)) {
      _compareFeatureIds.remove(featureId);
    } else {
      _compareFeatureIds.add(featureId);
    }
    notifyListeners();
    compileComparison();
  }

  void loadSnippet(Snippet snippet) {
    _currentSnippet = snippet;
    _code = snippet.code;
    _arch = snippet.recommendedArch;
    _optLevel = snippet.recommendedOpt;
    _selectedFeatureIds.clear();
    _selectedFeatureIds.addAll(snippet.recommendedFeatureIds);
    notifyListeners();
    compile();
  }

  Future<void> refreshSnippets() async {
    _snippets = await databaseService.searchSnippets(_searchQuery, category: _selectedCategory);
    final allCats = await databaseService.getCategories();
    _categories = ['All', ...allCats];
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    refreshSnippets();
  }

  void setSelectedCategory(String category) {
    _selectedCategory = category;
    refreshSnippets();
  }

  Future<void> saveSnippet({
    required String title,
    required String description,
    required String category,
  }) async {
    final newSnippet = Snippet(
      id: const Uuid().v4(),
      title: title,
      description: description,
      category: category,
      code: _code,
      recommendedArch: _arch,
      recommendedOpt: _optLevel,
      recommendedFeatureIds: _selectedFeatureIds.toList(),
      isPreset: false,
    );

    await databaseService.saveSnippet(newSnippet);
    _currentSnippet = newSnippet;
    await refreshSnippets();
  }

  Future<void> deleteSnippet(String id) async {
    await databaseService.deleteSnippet(id);
    if (_currentSnippet?.id == id) {
      _currentSnippet = _snippets.firstOrNull;
    }
    await refreshSnippets();
  }

  Future<void> compile() async {
    _isCompiling = true;
    notifyListeners();

    try {
      _result = await compilerService.compile(
        sourceCode: _code,
        arch: _arch,
        optLevel: _optLevel,
        cpuFlags: activeCpuFlags,
        syntax: _syntax,
        cleanDirectives: _cleanDirectives,
        extraFlags: _extraFlags,
      );

      if (_result != null && _result!.success) {
        databaseService.recordHistory(
          _result!,
          _currentSnippet?.title ?? 'Custom Snippet',
          _code,
        );
      }
    } finally {
      _isCompiling = false;
      notifyListeners();
    }

    if (_isComparisonMode) {
      compileComparison();
    }
  }

  Future<void> compileComparison() async {
    _isCompareCompiling = true;
    notifyListeners();

    try {
      _compareResult = await compilerService.compile(
        sourceCode: _code,
        arch: _compareArch,
        optLevel: _compareOptLevel,
        cpuFlags: compareActiveCpuFlags,
        syntax: _syntax,
        cleanDirectives: _cleanDirectives,
        extraFlags: _extraFlags,
      );
    } finally {
      _isCompareCompiling = false;
      notifyListeners();
    }
  }
}
