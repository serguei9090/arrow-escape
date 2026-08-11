import 'package:flutter/foundation.dart';
import '../../data/models/level.dart';
import '../../data/level_generator/solver.dart';

class SolveResult {
  final bool isSolvable;
  final List<String> solutionOrder;

  SolveResult({required this.isSolvable, required this.solutionOrder});
}

class EditorState extends ChangeNotifier {
  List<LevelModel> _levels = [];
  int? _selectedLevelIndex;

  String _searchQuery = '';
  Difficulty? _difficultyFilter;
  bool? _solvabilityFilter; // true = solvable, false = unsolvable, null = all

  final Map<int, bool> _solvabilityCache = {};
  bool _isAnalyzingAll = false;

  // Bulk Generator State
  bool _isBulkGenerating = false;
  double _bulkProgress = 0.0;
  String _bulkStatusLog = '';
  int _bulkGeneratedCount = 0;
  int _bulkSolvableCount = 0;

  List<LevelModel> get levels => _levels;
  int? get selectedLevelIndex => _selectedLevelIndex;

  LevelModel? get selectedLevel =>
      (_selectedLevelIndex != null && _selectedLevelIndex! < _levels.length)
          ? _levels[_selectedLevelIndex!]
          : null;

  String get searchQuery => _searchQuery;
  Difficulty? get difficultyFilter => _difficultyFilter;
  bool? get solvabilityFilter => _solvabilityFilter;

  bool get isAnalyzingAll => _isAnalyzingAll;
  bool get isBulkGenerating => _isBulkGenerating;
  double get bulkProgress => _bulkProgress;
  String get bulkStatusLog => _bulkStatusLog;
  int get bulkGeneratedCount => _bulkGeneratedCount;
  int get bulkSolvableCount => _bulkSolvableCount;

  void setLevels(List<LevelModel> newLevels) {
    _levels = List.from(newLevels);
    _selectedLevelIndex = _levels.isNotEmpty ? 0 : null;
    _solvabilityCache.clear();
    _reanalyzeSolvability();
    notifyListeners();
  }

  void selectLevel(int index) {
    if (index >= 0 && index < _levels.length) {
      _selectedLevelIndex = index;
      notifyListeners();
    }
  }

  void addLevel(LevelModel level) {
    _levels.add(level);
    _reorderLevelNumbers();
    _selectedLevelIndex = _levels.length - 1;
    notifyListeners();
  }

  void updateSelectedLevel(LevelModel updatedLevel) {
    if (_selectedLevelIndex != null && _selectedLevelIndex! < _levels.length) {
      _levels[_selectedLevelIndex!] = updatedLevel;
      _solvabilityCache[updatedLevel.levelNumber] = isLevelSolvable(updatedLevel);
      notifyListeners();
    }
  }

  void duplicateSelectedLevel() {
    final cur = selectedLevel;
    if (cur == null || _selectedLevelIndex == null) return;
    final copy = LevelModel(
      levelNumber: cur.levelNumber + 1,
      gridSize: cur.gridSize,
      arrows: cur.arrows.map((a) => a.copyWith()).toList(),
      patternName: '${cur.patternName} (Copy)',
      difficulty: cur.difficulty,
      solutionOrder: List.from(cur.solutionOrder),
      maskShape: cur.maskShape,
      mask: Set.from(cur.mask),
      orphanDots: cur.orphanDots
          .map((d) => OrphanDot(row: d.row, col: d.col, type: d.type))
          .toList(),
    );
    _levels.insert(_selectedLevelIndex! + 1, copy);
    _reorderLevelNumbers();
    _selectedLevelIndex = _selectedLevelIndex! + 1;
    notifyListeners();
  }

  void deleteSelectedLevel() {
    if (_selectedLevelIndex == null || _levels.isEmpty) return;
    _levels.removeAt(_selectedLevelIndex!);
    _reorderLevelNumbers();
    if (_levels.isEmpty) {
      _selectedLevelIndex = null;
    } else if (_selectedLevelIndex! >= _levels.length) {
      _selectedLevelIndex = _levels.length - 1;
    }
    notifyListeners();
  }

  void _reorderLevelNumbers() {
    for (int i = 0; i < _levels.length; i++) {
      final lvl = _levels[i];
      if (lvl.levelNumber != i + 1) {
        _levels[i] = LevelModel(
          levelNumber: i + 1,
          gridSize: lvl.gridSize,
          arrows: lvl.arrows,
          patternName: lvl.patternName,
          difficulty: lvl.difficulty,
          solutionOrder: lvl.solutionOrder,
          maskShape: lvl.maskShape,
          mask: lvl.mask,
          orphanDots: lvl.orphanDots,
        );
      }
    }
    _solvabilityCache.clear();
    _reanalyzeSolvability();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setDifficultyFilter(Difficulty? difficulty) {
    _difficultyFilter = difficulty;
    notifyListeners();
  }

  void setSolvabilityFilter(bool? solvability) {
    _solvabilityFilter = solvability;
    notifyListeners();
  }

  bool isLevelSolvable(LevelModel level) {
    if (_solvabilityCache.containsKey(level.levelNumber)) {
      return _solvabilityCache[level.levelNumber]!;
    }
    final res = LevelSolver.solve(level) != null;
    _solvabilityCache[level.levelNumber] = res;
    return res;
  }

  void _reanalyzeSolvability() {
    _isAnalyzingAll = true;
    for (final lvl in _levels) {
      _solvabilityCache[lvl.levelNumber] = LevelSolver.solve(lvl) != null;
    }
    _isAnalyzingAll = false;
  }

  int get solvableCount =>
      _solvabilityCache.values.where((s) => s == true).length;

  int get unsolvableCount =>
      _solvabilityCache.values.where((s) => s == false).length;

  List<LevelModel> get filteredLevels {
    return _levels.where((lvl) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final numMatch = lvl.levelNumber.toString() == q ||
            'level ${lvl.levelNumber}'.toLowerCase().contains(q);
        final nameMatch = lvl.patternName.toLowerCase().contains(q);
        if (!numMatch && !nameMatch) return false;
      }

      if (_difficultyFilter != null && lvl.difficulty != _difficultyFilter) {
        return false;
      }

      if (_solvabilityFilter != null) {
        final solvable = isLevelSolvable(lvl);
        if (solvable != _solvabilityFilter) return false;
      }

      return true;
    }).toList();
  }

  // Bulk Generator Actions
  void updateBulkProgress({
    required double progress,
    required String logLine,
    int? generatedCount,
    int? solvableCount,
    bool? isGenerating,
  }) {
    _bulkProgress = progress;
    _bulkStatusLog += '$logLine\n';
    if (generatedCount != null) _bulkGeneratedCount = generatedCount;
    if (solvableCount != null) _bulkSolvableCount = solvableCount;
    if (isGenerating != null) _isBulkGenerating = isGenerating;
    notifyListeners();
  }

  void resetBulkProgress() {
    _bulkProgress = 0.0;
    _bulkStatusLog = '';
    _bulkGeneratedCount = 0;
    _bulkSolvableCount = 0;
    _isBulkGenerating = false;
    notifyListeners();
  }
}
