import 'dart:convert';
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
  String _selectedYear = 'All';
  String _searchQuery = '';

  // Options lists populated from data
  List<String> _availableRegions = [];
  List<String> _availableYears = [];
  List<String> _uniqueTestNames = [];

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
  String get selectedYear => _selectedYear;
  String get searchQuery => _searchQuery;

  List<String> get availableRegions => _availableRegions;
  List<String> get availableYears => _availableYears;
  List<String> get uniqueTestNames => _uniqueTestNames;

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
      _uniqueTestNames = [];
      _selectedGender = 'All';
      _selectedRegion = 'All';
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

    // Collect unique years & unique tests
    final yearsSet = <int>{};
    final testsSet = <String>{};
    for (var p in _allPatients) {
      for (var entry in p.testHistory.entries) {
        testsSet.add(entry.key);
        yearsSet.addAll(entry.value.keys);
      }
    }
    final years = yearsSet.map((y) => y.toString()).toList()..sort();
    _availableYears = ['All', ...years];

    _uniqueTestNames = testsSet.toList()..sort();
  }

  // Unified File Parsing Entrypoint
  Future<void> parseFile(Uint8List bytes, String name, int size) async {
    _isLoading = true;
    _parseProgress = 0.0;
    _errorMessage = null;
    _fileName = name;
    _fileSize = size;
    notifyListeners();

    try {
      final cleanName = name.toLowerCase();
      if (cleanName.endsWith('.csv')) {
        await _parseCsvFile(bytes);
      } else if (cleanName.endsWith('.xlsx') || cleanName.endsWith('.xls')) {
        await _parseExcelFile(bytes);
      } else {
        throw Exception('Unsupported file format. Please upload .csv or .xlsx files.');
      }

      // Cache the parsed list in Hive
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

  // Fast CSV Parser (100x Faster)
  Future<void> _parseCsvFile(Uint8List bytes) async {
    final String csvText = utf8.decode(bytes);
    final List<String> lines = csvText.split(RegExp(r'\r?\n'));
    if (lines.isEmpty) return;

    // Detect header
    bool hasHeader = false;
    final firstLine = lines.first.toLowerCase();
    if (firstLine.contains('gender') || firstLine.contains('sex')) {
      hasHeader = true;
    }

    final startIdx = hasHeader ? 1 : 0;
    final int totalLinesToProcess = lines.length - startIdx;
    final Map<String, Patient> tempPatientMap = {};
    int processedLinesCount = 0;

    for (int i = startIdx; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // Simple CSV row parser handling optional quotes
      final List<String> row = line.split(',').map((cell) {
        return cell.replaceAll('"', '').trim();
      }).toList();

      if (row.length < 6) continue;

      final gender = row[0];
      final dob = row[1];
      final region = row[2];
      final testName = row[3].toUpperCase();
      final resultYearStr = row[4];
      final resultValueStr = row[5];

      if (testName.isEmpty || resultValueStr.isEmpty) continue;

      final resultYear = int.tryParse(resultYearStr) ?? 2025;
      
      // Parse numeric or dynamic value
      dynamic resultValue;
      final numericCheck = double.tryParse(resultValueStr);
      if (numericCheck != null) {
        resultValue = numericCheck;
      } else {
        resultValue = resultValueStr;
      }

      final key = '${gender}_${dob}_$region'.toLowerCase();

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

      if (!patient.testHistory.containsKey(testName)) {
        patient.testHistory[testName] = {};
      }
      patient.testHistory[testName]![resultYear] = resultValue;

      processedLinesCount++;

      // Yield back to browser microtasks every 5000 lines
      if (processedLinesCount % 5000 == 0) {
        _parseProgress = processedLinesCount / totalLinesToProcess;
        notifyListeners();
        await Future.delayed(Duration.zero);
      }
    }

    _allPatients = tempPatientMap.values.toList();
    _updateFiltersList();
  }

  // Optimized Excel Parser with Early Exit on Blank Rows
  Future<void> _parseExcelFile(Uint8List bytes) async {
    final Excel excel = Excel.decodeBytes(bytes);
    final String sheetName = excel.tables.keys.first;
    final Sheet sheet = excel.tables[sheetName]!;
    
    final int maxRows = sheet.maxRows;
    if (maxRows <= 1) {
      throw Exception('The uploaded sheet is empty or contains only headers.');
    }

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
    final Map<String, Patient> tempPatientMap = {};

    int processedRowsCount = 0;
    int consecutiveEmptyRows = 0;

    for (int i = startRow; i < maxRows; i++) {
      final row = sheet.rows[i];
      
      // Early exit if we encounter consecutive empty rows
      if (row.isEmpty || row[0]?.value == null) {
        consecutiveEmptyRows++;
        if (consecutiveEmptyRows >= 5) {
          // Break early as we reached the formatted empty zone at the bottom
          break;
        }
        continue;
      }
      
      consecutiveEmptyRows = 0; // Reset counter on valid row

      if (row.length < 6) continue;

      final gender = row[0]?.value?.toString().trim() ?? 'Unknown';
      final dob = row[1]?.value?.toString().trim() ?? 'Unknown';
      final region = row[2]?.value?.toString().trim() ?? 'Unknown';
      final testName = row[3]?.value?.toString().trim().toUpperCase() ?? '';
      final resultYearStr = row[4]?.value?.toString().trim() ?? '2025';
      final resultValue = row[5]?.value;

      if (testName.isEmpty || resultValue == null) continue;

      final resultYear = int.tryParse(resultYearStr) ?? 2025;
      final key = '${gender}_${dob}_$region'.toLowerCase();

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

      if (!patient.testHistory.containsKey(testName)) {
        patient.testHistory[testName] = {};
      }
      patient.testHistory[testName]![resultYear] = resultValue;

      processedRowsCount++;

      if (processedRowsCount % 2000 == 0) {
        _parseProgress = processedRowsCount / totalRowsToProcess;
        notifyListeners();
        await Future.delayed(Duration.zero);
      }
    }

    _allPatients = tempPatientMap.values.toList();
    _updateFiltersList();
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
      if (_selectedGender != 'All' &&
          patient.gender.toLowerCase() != _selectedGender.toLowerCase()) {
        return false;
      }

      if (_selectedRegion != 'All' &&
          patient.region.toLowerCase() != _selectedRegion.toLowerCase()) {
        return false;
      }

      int? targetYear;
      if (_selectedYear != 'All') {
        targetYear = int.tryParse(_selectedYear);
        if (targetYear == null) return false;

        bool hasTestInYear = false;
        for (var history in patient.testHistory.values) {
          if (history.containsKey(targetYear)) {
            hasTestInYear = true;
            break;
          }
        }
        if (!hasTestInYear) return false;
      }

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

  // Stats Card Info
  int get totalPatientsCount => _filteredPatients.length;
  int get totalUniqueTestsCount => _uniqueTestNames.length;
  int get totalRegionsCount => _availableRegions.length - 1; // Subtract 'All'

  int get malesCount => _filteredPatients.where((p) => p.gender.toLowerCase() == 'male' || p.gender.toLowerCase() == 'm').length;
  int get femalesCount => _filteredPatients.where((p) => p.gender.toLowerCase() == 'female' || p.gender.toLowerCase() == 'f').length;

  // Region Patient Counts (used for Saudi map outline)
  Map<String, int> get regionCounts {
    final Map<String, int> counts = {};
    for (var p in _filteredPatients) {
      final cleanRegion = p.region.trim();
      counts[cleanRegion] = (counts[cleanRegion] ?? 0) + 1;
    }
    return counts;
  }

  // Region analysis details (table representation)
  List<Map<String, dynamic>> get regionAnalysisTable {
    final Map<String, int> counts = regionCounts;
    final int total = totalPatientsCount;

    final List<Map<String, dynamic>> table = [];

    Patient.saudiRegionPopulations.forEach((regionName, population) {
      // Find matches in counts (accounting for variations)
      int count = 0;
      counts.forEach((key, val) {
        if (_isRegionMatch(key, regionName)) {
          count += val;
        }
      });

      final double prevalence = population > 0 ? (count / population) * 100 : 0.0;
      final double cohortShare = total > 0 ? (count / total) * 100 : 0.0;

      table.add({
        'region': regionName,
        'population': population,
        'patients': count,
        'prevalence': double.parse(prevalence.toStringAsFixed(5)), // Prevalence is usually small
        'cohortShare': double.parse(cohortShare.toStringAsFixed(2)),
      });
    });

    // Sort table by patient count descending
    table.sort((a, b) => (b['patients'] as int).compareTo(a['patients'] as int));
    return table;
  }

  bool _isRegionMatch(String input, String target) {
    final cleanInput = input.toLowerCase().trim();
    final cleanTarget = target.toLowerCase().trim();

    if (cleanInput == cleanTarget) return true;
    if (cleanTarget.contains('eastern') && (cleanInput.contains('eastern') || cleanInput.contains('الشرقية') || cleanInput.contains('dammam'))) return true;
    if (cleanTarget.contains('riyadh') && (cleanInput.contains('riyadh') || cleanInput.contains('الرياض') || cleanInput.contains('riyad'))) return true;
    if (cleanTarget.contains('makkah') && (cleanInput.contains('makkah') || cleanInput.contains('mecca') || cleanInput.contains('مكة'))) return true;
    if (cleanTarget.contains('madinah') && (cleanInput.contains('madinah') || cleanInput.contains('madina') || cleanInput.contains('المدينة'))) return true;
    if (cleanTarget.contains('qassim') && (cleanInput.contains('qassim') || cleanInput.contains('القصيم') || cleanInput.contains('gassim'))) return true;
    if (cleanTarget.contains('hail') && (cleanInput.contains('hail') || cleanInput.contains('حائل'))) return true;
    if (cleanTarget.contains('tabuk') && (cleanInput.contains('tabuk') || cleanInput.contains('تبوك'))) return true;
    if (cleanTarget.contains('jawf') && (cleanInput.contains('jawf') || cleanInput.contains('الجوف'))) return true;
    if (cleanTarget.contains('borders') && (cleanInput.contains('border') || cleanInput.contains('شمالية') || cleanInput.contains('arar'))) return true;
    if (cleanTarget.contains('jazan') && (cleanInput.contains('jazan') || cleanInput.contains('jizan') || cleanInput.contains('جازان'))) return true;
    if (cleanTarget.contains('asir') && (cleanInput.contains('asir') || cleanInput.contains('عسير') || cleanInput.contains('abha'))) return true;
    if (cleanTarget.contains('najran') && (cleanInput.contains('najran') || cleanInput.contains('نجران'))) return true;
    if (cleanTarget.contains('bahah') && (cleanInput.contains('bahah') || cleanInput.contains('الباحة'))) return true;

    return false;
  }

  // Dynamic test breakdown
  Map<String, int> getTestResultBreakdown(String testName, [int? targetYear]) {
    final Map<String, int> breakdown = {};
    final String targetTest = testName.toUpperCase().trim();

    for (var p in _filteredPatients) {
      final val = p.getLatestValue(targetTest, targetYear);
      if (val == null) continue;

      // Classify based on clinical test type
      if (targetTest == 'ALT' || targetTest == 'AST') {
        final numVal = p.getNumericValue(targetTest, targetYear);
        if (numVal != null) {
          final label = numVal <= 40 ? 'Normal (<= 40 U/L)' : 'Elevated (> 40 U/L)';
          breakdown[label] = (breakdown[label] ?? 0) + 1;
        }
      } else if (targetTest == 'PLATELETS' || targetTest == 'PLT') {
        final numVal = p.getNumericValue(targetTest, targetYear);
        if (numVal != null) {
          // Adjust for platelet units (normal range >= 150)
          double limit = 150;
          if (numVal > 1000) {
            limit = 150000;
          }
          final label = numVal >= limit ? 'Normal (>= 150)' : 'Low (< 150)';
          breakdown[label] = (breakdown[label] ?? 0) + 1;
        }
      } else if (targetTest == 'HBV DNA' || targetTest == 'HBV_DNA' || targetTest == 'VIRAL LOAD' || targetTest == 'PCR') {
        final numVal = p.getNumericValue(targetTest, targetYear);
        if (numVal != null) {
          String label;
          if (numVal < 10) {
            label = 'Undetectable (< 10 IU/mL)';
          } else if (numVal < 2000) {
            label = 'Low (< 2,000 IU/mL)';
          } else if (numVal <= 20000) {
            label = 'Moderate (2,000 - 20,000)';
          } else {
            label = 'High (> 20,000 IU/mL)';
          }
          breakdown[label] = (breakdown[label] ?? 0) + 1;
        }
      } else {
        // Qualitative / Generic test (like HBsAg, HBeAg or others)
        String label = val.toString().toLowerCase().trim();
        // Capitalize for cleaner UI
        if (label == 'positive' || label == 'reactive' || label == 'موجب') {
          label = 'Positive / Reactive';
        } else if (label == 'negative' || label == 'non-reactive' || label == 'سالب') {
          label = 'Negative / Non-reactive';
        } else {
          label = label.toUpperCase();
        }
        breakdown[label] = (breakdown[label] ?? 0) + 1;
      }
    }

    return breakdown;
  }

  // Get numerical statistics for test card (Min, Max, Mean)
  Map<String, double> getTestNumericalStats(String testName, [int? targetYear]) {
    final list = _filteredPatients
        .map((p) => p.getNumericValue(testName, targetYear))
        .whereType<double>()
        .toList();

    if (list.isEmpty) return {};

    final minVal = list.reduce((a, b) => a < b ? a : b);
    final maxVal = list.reduce((a, b) => a > b ? a : b);
    final meanVal = list.reduce((a, b) => a + b) / list.length;

    return {
      'min': double.parse(minVal.toStringAsFixed(1)),
      'max': double.parse(maxVal.toStringAsFixed(1)),
      'mean': double.parse(meanVal.toStringAsFixed(1)),
    };
  }
}
