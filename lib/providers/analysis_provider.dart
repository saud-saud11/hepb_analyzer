import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/patient_model.dart';

class AnalysisProvider extends ChangeNotifier {
  List<Patient> _allPatients = [];
  List<Patient> _filteredPatients = [];
  bool _isLoading = false;
  double _parseProgress = 0.0;
  String? _fileName;
  int? _fileSize;
  String? _errorMessage;

  // Cache Box
  static const String boxName = 'patients_cache_box';
  late Box _cacheBox;

  // Filters
  String _selectedGender = 'All';
  String _selectedRegion = 'All';
  String _selectedPhase = 'All';
  String _selectedFibrosis = 'All';
  String _selectedYear = 'All';
  String _searchQuery = '';

  // Options lists populated from data
  List<String> _availableRegions = [];
  List<String> _availableYears = [];

  // Getters
  List<Patient> get patients => _filteredPatients;
  List<Patient> get allPatients => _allPatients;
  bool get isLoading => _isLoading;
  double get parseProgress => _parseProgress;
  String? get fileName => _fileName;
  int? get fileSize => _fileSize;
  String? get errorMessage => _errorMessage;

  String get selectedGender => _selectedGender;
  String get selectedRegion => _selectedRegion;
  String get selectedPhase => _selectedPhase;
  String get selectedFibrosis => _selectedFibrosis;
  String get selectedYear => _selectedYear;
  String get searchQuery => _searchQuery;

  List<String> get availableRegions => _availableRegions;
  List<String> get availableYears => _availableYears;

  AnalysisProvider() {
    _initHive();
  }

  Future<void> _initHive() async {
    _isLoading = true;
    notifyListeners();
    try {
      _cacheBox = await Hive.openBox(boxName);
      _loadCachedData();
    } catch (e) {
      _errorMessage = 'Failed to initialize local database: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _loadCachedData() {
    try {
      final cachedList = _cacheBox.get('patients_list');
      if (cachedList != null && cachedList is List) {
        _allPatients = cachedList
            .map((item) => Patient.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        _fileName = _cacheBox.get('file_name');
        _fileSize = _cacheBox.get('file_size');
        _updateFiltersList();
        _applyFilters();
      }
    } catch (e) {
      _errorMessage = 'Failed to load cached patients: $e';
    }
  }

  Future<void> clearCache() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _cacheBox.clear();
      _allPatients = [];
      _filteredPatients = [];
      _fileName = null;
      _fileSize = null;
      _availableRegions = [];
      _availableYears = [];
      _selectedGender = 'All';
      _selectedRegion = 'All';
      _selectedPhase = 'All';
      _selectedFibrosis = 'All';
      _selectedYear = 'All';
      _searchQuery = '';
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to clear cache: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _updateFiltersList() {
    // Collect unique regions
    final regions = _allPatients.map((p) => p.region).toSet().toList()..sort();
    _availableRegions = ['All', ...regions];

    // Collect unique years from test histories
    final yearsSet = <int>{};
    for (var p in _allPatients) {
      for (var testHistory in p.testHistory.values) {
        yearsSet.addAll(testHistory.keys);
      }
    }
    final years = yearsSet.map((y) => y.toString()).toList()..sort();
    _availableYears = ['All', ...years];
  }

  // Parse Excel Bytes
  Future<void> parseExcelFile(Uint8List bytes, String name, int size) async {
    _isLoading = true;
    _parseProgress = 0.0;
    _errorMessage = null;
    _fileName = name;
    _fileSize = size;
    notifyListeners();

    try {
      // Decode Excel sheet using excel package
      final Excel excel = Excel.decodeBytes(bytes);
      
      // Get the first table/sheet
      final String sheetName = excel.tables.keys.first;
      final Sheet sheet = excel.tables[sheetName]!;
      
      final int maxRows = sheet.maxRows;
      if (maxRows <= 1) {
        throw Exception('The uploaded sheet is empty or contains only headers.');
      }

      // Check for headers.
      // Expected columns: gender, dateofbirth, region_en, test_name, result_year, result_value
      final firstRow = sheet.rows.first;
      bool hasHeader = false;
      if (firstRow.isNotEmpty) {
        final cell0 = firstRow[0]?.value?.toString().toLowerCase() ?? '';
        if (cell0.contains('gender') || cell0.contains('sex')) {
          hasHeader = true;
        }
      }

      final startRow = hasHeader ? 1 : 0;
      final int totalRowsToProcess = maxRows - startRow;
      
      // Patient aggregator: Map key -> Patient
      // Key format: "gender_dob_region"
      final Map<String, Patient> tempPatientMap = {};

      int processedRowsCount = 0;

      for (int i = startRow; i < maxRows; i++) {
        final row = sheet.rows[i];
        if (row.isEmpty || row.length < 6) continue;

        // Extract values
        final gender = row[0]?.value?.toString().trim() ?? 'Unknown';
        final dob = row[1]?.value?.toString().trim() ?? 'Unknown';
        final region = row[2]?.value?.toString().trim() ?? 'Unknown';
        final testName = row[3]?.value?.toString().trim().toUpperCase() ?? '';
        final resultYearStr = row[4]?.value?.toString().trim() ?? '2025';
        final resultValue = row[5]?.value;

        if (testName.isEmpty || resultValue == null) continue;

        final resultYear = int.tryParse(resultYearStr) ?? 2025;

        // Group key
        final key = '${gender}_${dob}_$region'.toLowerCase();

        // Retrieve or create patient
        Patient patient;
        if (tempPatientMap.containsKey(key)) {
          patient = tempPatientMap[key]!;
        } else {
          patient = Patient(
            gender: gender,
            dateOfBirth: dob,
            region: region,
            testHistory: {},
          );
          tempPatientMap[key] = patient;
        }

        // Add test result to patient's test history
        if (!patient.testHistory.containsKey(testName)) {
          patient.testHistory[testName] = {};
        }
        patient.testHistory[testName]![resultYear] = resultValue;

        processedRowsCount++;

        // Yield to event loop every 2000 rows to keep web browser responsive and update progress
        if (processedRowsCount % 2000 == 0) {
          _parseProgress = processedRowsCount / totalRowsToProcess;
          notifyListeners();
          await Future.delayed(Duration.zero);
        }
      }

      // Convert map to list of patients
      _allPatients = tempPatientMap.values.toList();
      _updateFiltersList();

      // Save to Hive cache Box
      final List<Map<String, dynamic>> jsonList = _allPatients.map((p) => p.toJson()).toList();
      await _cacheBox.put('patients_list', jsonList);
      await _cacheBox.put('file_name', name);
      await _cacheBox.put('file_size', size);

      _applyFilters();
    } catch (e) {
      _errorMessage = 'Parsing failed: $e';
    } finally {
      _isLoading = false;
      _parseProgress = 1.0;
      notifyListeners();
    }
  }

  // Setters for filters
  void setGenderFilter(String val) {
    _selectedGender = val;
    _applyFilters();
  }

  void setRegionFilter(String val) {
    _selectedRegion = val;
    _applyFilters();
  }

  void setPhaseFilter(String val) {
    _selectedPhase = val;
    _applyFilters();
  }

  void setFibrosisFilter(String val) {
    _selectedFibrosis = val;
    _applyFilters();
  }

  void setYearFilter(String val) {
    _selectedYear = val;
    _applyFilters();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  // Apply filters
  void _applyFilters() {
    _filteredPatients = _allPatients.where((patient) {
      // 1. Gender Filter
      if (_selectedGender != 'All' &&
          patient.gender.toLowerCase() != _selectedGender.toLowerCase()) {
        return false;
      }

      // 2. Region Filter
      if (_selectedRegion != 'All' &&
          patient.region.toLowerCase() != _selectedRegion.toLowerCase()) {
        return false;
      }

      // 3. Year Filter
      int? targetYear;
      if (_selectedYear != 'All') {
        targetYear = int.tryParse(_selectedYear);
        if (targetYear == null) return false;

        // Check if patient has any test in this year
        bool hasTestInYear = false;
        for (var history in patient.testHistory.values) {
          if (history.containsKey(targetYear)) {
            hasTestInYear = true;
            break;
          }
        }
        if (!hasTestInYear) return false;
      }

      // 4. Disease Phase Filter
      if (_selectedPhase != 'All') {
        final phase = patient.getDiseasePhase(targetYear);
        if (phase.toString().split('.').last != _selectedPhase) {
          return false;
        }
      }

      // 5. Fibrosis Risk Filter
      if (_selectedFibrosis != 'All') {
        final risk = patient.getFibrosisRisk(targetYear);
        if (risk.toString().split('.').last != _selectedFibrosis) {
          return false;
        }
      }

      // 6. Search Query (Matches region, gender, dob, or region_en)
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesRegion = patient.region.toLowerCase().contains(q);
        final matchesGender = patient.gender.toLowerCase().contains(q);
        final matchesDob = patient.dateOfBirth.toLowerCase().contains(q);
        return matchesRegion || matchesGender || matchesDob;
      }

      return true;
    }).toList();

    notifyListeners();
  }

  // Analytics Aggregates (filtered)
  int get totalPatientsCount => _filteredPatients.length;

  int get malesCount => _filteredPatients.where((p) => p.gender.toLowerCase() == 'male' || p.gender.toLowerCase() == 'm').length;
  int get femalesCount => _filteredPatients.where((p) => p.gender.toLowerCase() == 'female' || p.gender.toLowerCase() == 'f').length;

  Map<HepBPhase, int> get phaseDistribution {
    final Map<HepBPhase, int> dist = {
      HepBPhase.immuneTolerant: 0,
      HepBPhase.activeHBeAgPositive: 0,
      HepBPhase.inactiveCarrier: 0,
      HepBPhase.activeHBeAgNegative: 0,
      HepBPhase.resolved: 0,
      HepBPhase.vaccinated: 0,
      HepBPhase.susceptible: 0,
      HepBPhase.indeterminate: 0,
    };
    int? targetYear = _selectedYear != 'All' ? int.tryParse(_selectedYear) : null;

    for (var p in _filteredPatients) {
      final phase = p.getDiseasePhase(targetYear);
      dist[phase] = (dist[phase] ?? 0) + 1;
    }
    return dist;
  }

  Map<FibrosisRiskLevel, int> get fibrosisDistribution {
    final Map<FibrosisRiskLevel, int> dist = {
      FibrosisRiskLevel.low: 0,
      FibrosisRiskLevel.indeterminate: 0,
      FibrosisRiskLevel.high: 0,
      FibrosisRiskLevel.unknown: 0,
    };
    int? targetYear = _selectedYear != 'All' ? int.tryParse(_selectedYear) : null;

    for (var p in _filteredPatients) {
      final risk = p.getFibrosisRisk(targetYear);
      dist[risk] = (dist[risk] ?? 0) + 1;
    }
    return dist;
  }

  // Region Patient Counts (used for Saudi map)
  Map<String, int> get regionCounts {
    final Map<String, int> counts = {};
    for (var p in _filteredPatients) {
      final cleanRegion = p.region.trim();
      counts[cleanRegion] = (counts[cleanRegion] ?? 0) + 1;
    }
    return counts;
  }

  // Get average ALT / AST / Platelets
  double get averageAlt {
    int? targetYear = _selectedYear != 'All' ? int.tryParse(_selectedYear) : null;
    final list = _filteredPatients.map((p) => p.getAlt(targetYear)).whereType<double>().toList();
    if (list.isEmpty) return 0.0;
    return double.parse((list.reduce((a, b) => a + b) / list.length).toStringAsFixed(1));
  }

  double get averageAst {
    int? targetYear = _selectedYear != 'All' ? int.tryParse(_selectedYear) : null;
    final list = _filteredPatients.map((p) => p.getAst(targetYear)).whereType<double>().toList();
    if (list.isEmpty) return 0.0;
    return double.parse((list.reduce((a, b) => a + b) / list.length).toStringAsFixed(1));
  }

  double get averagePlatelets {
    int? targetYear = _selectedYear != 'All' ? int.tryParse(_selectedYear) : null;
    final list = _filteredPatients.map((p) => p.getPlatelets(targetYear)).whereType<double>().toList();
    if (list.isEmpty) return 0.0;
    return double.parse((list.reduce((a, b) => a + b) / list.length).toStringAsFixed(1));
  }

  // Average FIB-4
  double get averageFib4 {
    int? targetYear = _selectedYear != 'All' ? int.tryParse(_selectedYear) : null;
    final list = _filteredPatients.map((p) => p.getFib4(targetYear)).whereType<double>().toList();
    if (list.isEmpty) return 0.0;
    return double.parse((list.reduce((a, b) => a + b) / list.length).toStringAsFixed(2));
  }
}
